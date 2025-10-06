package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/fs"
	"log"
	"math/rand"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

// ---------------------
// Structs
// ---------------------

type HostConfig struct {
	ClientHost string `yaml:"client_host"`
	SutHost    string `yaml:"sut_host"`
}

type QueryConfig struct {
	QueryID      int `yaml:"query_id"`
	Trajectories int `yaml:"trajectories"`
}

type ExecutionBlock struct {
	Repetitions int           `yaml:"repetitions"`
	Concurrency int           `yaml:"concurrency"`
	Queries     []QueryConfig `yaml:"queries"`
}

// Top-level config: dynamic keys (warmup, execution1, execution2, …)
type BenchConfig map[string]ExecutionBlock

// ---------------------
// Request structs
// ---------------------

type Request struct {
	RunID        string       `json:"run_id"`
	BaseURL      string       `json:"base_url"`
	Concurrency  int          `json:"concurrency"`
	QueryConfigs []QueryEntry `json:"query_configs"`
}

type QueryEntry struct {
	QueryID       int      `json:"query_id"`
	TrajectoryIDs []string `json:"trajectory_ids"`
}

// ---------------------
// Helpers
// ---------------------

func loadHosts(path string) (map[string]HostConfig, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var hosts map[string]HostConfig
	if err := yaml.Unmarshal(data, &hosts); err != nil {
		return nil, err
	}
	return hosts, nil
}

func loadBenchConfig(path string) (BenchConfig, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var cfg BenchConfig
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}
	return cfg, nil
}

func listTrajectories(folder string) ([]string, error) {
	var ids []string
	err := filepath.WalkDir(folder, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !d.IsDir() && strings.HasSuffix(d.Name(), ".csv") {
			id := strings.TrimSuffix(d.Name(), ".csv")
			ids = append(ids, id)
		}
		return nil
	})
	return ids, err
}

func pickRandom(ids []string, n int) []string {
	if n > len(ids) {
		n = len(ids)
	}
	rand.Shuffle(len(ids), func(i, j int) { ids[i], ids[j] = ids[j], ids[i] })
	return ids[:n]
}

// ---------------------
// Main
// ---------------------

func main() {
	rand.Seed(time.Now().UnixNano())

	// Load configs
	hosts, err := loadHosts("hosts.yml")
	if err != nil {
		log.Fatal(err)
	}
	benchCfg, err := loadBenchConfig("experiment.yml")
	if err != nil {
		log.Fatal(err)
	}
	trajectories, err := listTrajectories("simra")
	if err != nil {
		log.Fatal(err)
	}

	// Iterate executions
	for runID, block := range benchCfg {
		fmt.Printf("=== Run: %s ===\n", runID)
		for id, host := range hosts {
			fmt.Printf("-> Host: %s\n", id)

			for rep := 1; rep <= block.Repetitions; rep++ {
				// Shuffle queries for this host + repetition
				shuffled := make([]QueryConfig, len(block.Queries))
				copy(shuffled, block.Queries)
				rand.Shuffle(len(shuffled), func(i, j int) { shuffled[i], shuffled[j] = shuffled[j], shuffled[i] })

				var queryEntries []QueryEntry
				for _, q := range shuffled {
					trajIDs := pickRandom(trajectories, q.Trajectories)
					queryEntries = append(queryEntries, QueryEntry{
						QueryID:       q.QueryID,
						TrajectoryIDs: trajIDs,
					})
				}

				req := Request{
					RunID:        fmt.Sprintf("%s_%d", runID, rep),
					BaseURL:      host.SutHost,
					Concurrency:  block.Concurrency,
					QueryConfigs: queryEntries,
				}

				// Marshal to JSON
				body, _ := json.MarshalIndent(req, "", "  ")
				fmt.Printf("Request for %s (rep %d):\n%s\n\n", id, rep, string(body))

				// Here you’d send to client_host with http.Post
				resp, err := http.Post(host.ClientHost, "application/json", bytes.NewReader(body))
				if err != nil {
					log.Printf("Error sending request for %s (rep %d): %v\n", id, rep, err)
					continue
				}
				defer resp.Body.Close()

				if resp.StatusCode != http.StatusOK {
					log.Printf("Unexpected response for %s (rep %d): %s\n", id, rep, resp.Status)
					continue
				}

			}
		}
	}
}
