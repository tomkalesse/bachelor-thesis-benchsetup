package main

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"rasdaman/client/internal"
)

func main() {

	qm := internal.NewQueryManager("./simra")
	err := qm.LoadQueries("queries.yaml")
	if err != nil {
		fmt.Printf("Error loading queries: %v\n", err)
		return
	}
	var list []string

	endpoint := "http://188.34.96.4:8080/rasdaman/ows"

	query, _ := qm.ConstructQuery(2, nil, "trip001", list)
	log.Println(query)

	form := url.Values{}
	form.Set("service", "WCS")
	form.Set("version", "2.0.1")
	form.Set("request", "ProcessCoverages")
	form.Set("query", query)

	// POST form
	resp, err := http.PostForm(endpoint, form)
	if err != nil {
		panic(err)
	}
	defer resp.Body.Close()

	// Read response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		panic(err)
	}

	if resp.StatusCode != http.StatusOK {
		fmt.Printf("RasQL query failed: %d\nResponse: %s\n", resp.StatusCode, string(body))
		return
	}

	fmt.Println("Query successful, result:")
	fmt.Println(string(body))
}

func test() {
	// host := os.Getenv("HOST")
	// endpoint := "http://" + host + ":8080/rasdaman/ows"
	endpoint := "http://188.34.64.59:8080/rasdaman/ows"

	// RasQL query
	query := `
	for $c in (DWDradolan_5min)
	return encode(
		clip($c,
			LINESTRING(
				"2022-01-01T12:05" 52.531019 13.339950,
				"2022-01-01T12:10" 52.531204 13.339946,
				"2022-01-01T12:15" 52.540991 13.385492,
				"2022-01-01T12:25" 52.540991 13.385492,
				"2022-01-01T12:35" 52.540991 13.385492,
				"2022-01-01T12:45" 52.540991 13.385492,
				"2022-01-01T12:55" 52.540991 13.385492,
				"2022-01-02T12:45" 52.540991 13.385492,
				"2022-01-02T12:25" 52.540991 13.385492,
				"2022-01-03T12:25" 52.540991 13.385492,
				"2022-01-04T12:15" 52.540991 13.385492,
				"2022-01-05T12:15" 52.540991 13.385492,
				"2022-01-06T12:15" 52.540991 13.385492,
				"2022-01-07T12:15" 52.540991 13.385492),
			"http://localhost:8080/def/crs/EPSG/0/4326"),
		"json")
	`

	// Build form data
	form := url.Values{}
	form.Set("service", "WCS")
	form.Set("version", "2.0.1")
	form.Set("request", "ProcessCoverages")
	form.Set("query", query)

	// POST form
	resp, err := http.PostForm(endpoint, form)
	if err != nil {
		panic(err)
	}
	defer resp.Body.Close()

	// Read response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		panic(err)
	}

	if resp.StatusCode != http.StatusOK {
		fmt.Printf("RasQL query failed: %d\nResponse: %s\n", resp.StatusCode, string(body))
		return
	}

	fmt.Println("Query successful, result:")
	fmt.Println(string(body))
}
