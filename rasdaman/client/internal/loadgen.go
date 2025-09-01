package internal

import (
	"bytes"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"
)

type Result struct {
	WorkerID   int
	StatusCode int
	Latency    time.Duration
	Error      string
}

type Payload struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

func worker(id int, jobs <-chan int, results chan<- Result, wg *sync.WaitGroup, url string, payloads []Payload) {
	defer wg.Done()
	transport := &http.Transport{
		MaxIdleConns:        1000,
		MaxIdleConnsPerHost: 1000,
		MaxConnsPerHost:     0, // 0 = unlimited
		IdleConnTimeout:     90 * time.Second,
	}

	client := &http.Client{
		Timeout:   90 * time.Second,
		Transport: transport,
	}

	for jobID := range jobs {
		// Pick a payload (rotate over slice)
		payload := payloads[jobID%len(payloads)]

		body, err := json.Marshal(payload)
		if err != nil {
			log.Fatal(err)
		}

		req, _ := http.NewRequest("POST", url, bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")

		start := time.Now()
		resp, err := client.Do(req)
		latency := time.Since(start)

		res := Result{WorkerID: id, Latency: latency}

		if err != nil {
			res.Error = err.Error()
		} else {
			res.StatusCode = resp.StatusCode
			io.Copy(io.Discard, resp.Body)
			resp.Body.Close()
		}

		// Send result to collector
		results <- res

		// Console logging
		if res.Error != "" {
			fmt.Printf("Worker %d: error: %v\n", id, res.Error)
		} else {
			fmt.Printf("Worker %d: status %d, latency %v (payload ID=%d)\n",
				id, res.StatusCode, res.Latency, payload.ID)
		}
	}
}

func loadgen() {
	url := "example.com"
	concurrency := 10
	requests := 100

	// Prepare some rotating payloads
	payloads := []Payload{
		{ID: 1, Name: "Payload 1"},
		{ID: 2, Name: "Payload 2"},
		{ID: 3, Name: "Payload 3"},
	}

	jobs := make(chan int, requests)
	results := make(chan Result, requests)
	var wg sync.WaitGroup

	// Start workers
	for w := 0; w < concurrency; w++ {
		wg.Add(1)
		go worker(w, jobs, results, &wg, url, payloads)
	}

	// Feed jobs
	for j := 0; j < requests; j++ {
		jobs <- j
	}
	close(jobs)

	// Close results after workers finish
	go func() {
		wg.Wait()
		close(results)
	}()

	// Save results to CSV
	file, err := os.Create("results.csv")
	if err != nil {
		panic(err)
	}
	defer file.Close()

	writer := csv.NewWriter(file)
	defer writer.Flush()

	// CSV header
	writer.Write([]string{"worker_id", "status_code", "latency_ms", "error"})

	for r := range results {
		writer.Write([]string{
			strconv.Itoa(r.WorkerID),
			strconv.Itoa(r.StatusCode),
			strconv.FormatFloat(float64(r.Latency.Milliseconds()), 'f', -1, 64),
			r.Error,
		})
	}
}
