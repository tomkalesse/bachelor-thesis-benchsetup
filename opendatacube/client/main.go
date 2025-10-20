package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"opendatacube/client/internal"
	"os"
	"time"
)

type Config struct {
	RunID        string        `json:"run_id"`
	BaseURL      string        `json:"base_url"`
	Concurrency  int           `json:"concurrency"`
	QueryConfigs []queryConfig `json:"query_configs"`
}

type queryConfig struct {
	QueryID       int      `json:"query_id"`
	TrajectoryIDs []string `json:"trajectory_ids"`
}

func main() {

	qm := internal.NewQueryManager("./simra")
	err := qm.LoadQueries("queries.yaml")
	if err != nil {
		fmt.Printf("Error loading queries: %v\n", err)
		return
	}

	mux := http.NewServeMux()
	mux.HandleFunc("POST /request", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Only POST method is allowed", http.StatusMethodNotAllowed)
			return
		}
		// retrieve body
		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "Failed to read request body", http.StatusBadRequest)
			return
		}
		defer r.Body.Close()

		// unmarshal body to config struct
		var config Config
		var payload []internal.Payload
		if err := json.Unmarshal(body, &config); err != nil {
			http.Error(w, "Failed to unmarshal request body", http.StatusBadRequest)
			return
		}

		for i, c := range config.QueryConfigs {
			query, err := qm.ConstructQuery(c.QueryID, c.TrajectoryIDs)
			if err != nil {
				http.Error(w, fmt.Sprintf("Failed to construct query for config %d: %v", i, err), http.StatusBadRequest)
				return
			}
			payload = append(payload, internal.Payload{ID: i + 1, Query: query})
		}

		start := time.Now()
		internal.Loadgen(config.RunID, config.BaseURL, config.Concurrency, len(config.QueryConfigs), payload)
		latency := time.Since(start)
		txtFile, err := os.Create("./results/results_" + config.RunID + ".txt")
		if err != nil {
			panic(err)
		}
		defer txtFile.Close()
		txtFile.WriteString(fmt.Sprintf("%v\n", latency))

		w.WriteHeader(http.StatusOK)
		w.Write([]byte("Request received"))
	})

	server := &http.Server{
		Addr:    ":8080",
		Handler: mux,
	}

	log.Println("Starting server on :8080")
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Could not listen on :8080: %v\n", err)
	}
}
