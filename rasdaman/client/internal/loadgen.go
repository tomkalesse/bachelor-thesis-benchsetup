package internal

import (
	"bytes"
	"encoding/csv"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"sync"
	"time"
)

type Result struct {
	WorkerID     int
	JobID        int
	StatusCode   int
	Latency      time.Duration
	Error        string
	ResponseBody string
}

type Payload struct {
	ID    int    `json:"id"`
	Query string `json:"query"`
}

func worker(id int, jobs <-chan int, results chan<- Result, wg *sync.WaitGroup, baseURL string, payloads []Payload) {
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
		payload := payloads[jobID]

		form := url.Values{}
		form.Set("service", "WCS")
		form.Set("version", "2.0.1")
		form.Set("request", "ProcessCoverages")
		form.Set("query", payload.Query)
		log.Println("Submitting query:\n", payload.Query)

		req, _ := http.NewRequest("POST", baseURL, bytes.NewBufferString(form.Encode()))
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

		start := time.Now()
		resp, err := client.Do(req)
		latency := time.Since(start)

		res := Result{WorkerID: id, JobID: jobID, Latency: latency}

		if err != nil {
			res.Error = err.Error()
		} else {
			res.StatusCode = resp.StatusCode
			bodyBytes, readErr := io.ReadAll(resp.Body)
			resp.Body.Close()

			if readErr != nil {
				res.Error = readErr.Error()
			} else {
				res.ResponseBody = string(bodyBytes)
			}
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

func Loadgen(runId string, url string, concurrency int, requests int, payloads []Payload) {

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
	file, err := os.Create("./results/results_" + runId + ".csv")
	if err != nil {
		panic(err)
	}
	defer file.Close()

	writer := csv.NewWriter(file)
	defer writer.Flush()

	// CSV header
	writer.Write([]string{"worker_id", "job_id", "status_code", "latency_ms", "error", "response_body"})

	for r := range results {
		writer.Write([]string{
			strconv.Itoa(r.WorkerID),
			strconv.Itoa(r.JobID),
			strconv.Itoa(r.StatusCode),
			strconv.FormatFloat(float64(r.Latency.Milliseconds()), 'f', -1, 64),
			r.Error,
			r.ResponseBody,
		})
	}
}
