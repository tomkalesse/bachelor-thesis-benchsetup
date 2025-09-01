package internal

import (
	"encoding/csv"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"gopkg.in/yaml.v2"
)

// Placeholder represents a placeholder definition in the YAML
type Placeholder struct {
	Type     string `yaml:"type"`
	Keyword  string `yaml:"keyword"`
	Template string `yaml:"template,omitempty"`
}

// QueryItem represents a single query template in the YAML file
type QueryItem struct {
	ID           int           `yaml:"id"`
	Title        string        `yaml:"title"`
	Description  string        `yaml:"description"`
	Placeholders []Placeholder `yaml:"placeholders"`
	Query        string        `yaml:"query"`
}

// TrajectoryPoint represents a single point in a trajectory
type TrajectoryPoint struct {
	Timestamp string
	Latitude  float64
	Longitude float64
}

// Trajectory represents a collection of trajectory points
type Trajectory []TrajectoryPoint

// QueryManager manages query templates and constructs actual queries
type QueryManager struct {
	queries     map[int]QueryItem // queries indexed by ID
	simraFolder string
}

// NewQueryManager creates a new query manager
func NewQueryManager(simraFolder string) *QueryManager {
	return &QueryManager{
		queries:     make(map[int]QueryItem),
		simraFolder: simraFolder,
	}
}

// LoadQueries loads all query templates from YAML file into memory
func (qm *QueryManager) LoadQueries(yamlFile string) error {
	data, err := os.ReadFile(yamlFile)
	if err != nil {
		return fmt.Errorf("failed to read YAML file: %v", err)
	}

	// Split the YAML content into separate documents
	yamlDocs := strings.Split(string(data), "\n\n")

	for _, doc := range yamlDocs {
		if strings.TrimSpace(doc) == "" {
			continue
		}

		var query QueryItem
		if err := yaml.Unmarshal([]byte(doc), &query); err != nil {
			return fmt.Errorf("failed to parse YAML document: %v", err)
		}

		if query.ID != 0 {
			qm.queries[query.ID] = query
		}
	}

	fmt.Printf("Loaded %d query templates into memory\n", len(qm.queries))
	return nil
}

// GetQueryTemplate returns a query template by ID
func (qm *QueryManager) GetQueryTemplate(queryID int) (QueryItem, error) {
	query, exists := qm.queries[queryID]
	if !exists {
		return QueryItem{}, fmt.Errorf("query with ID %d not found", queryID)
	}
	return query, nil
}

// ListQueries returns all available query IDs and titles
func (qm *QueryManager) ListQueries() map[int]string {
	result := make(map[int]string)
	for id, query := range qm.queries {
		result[id] = query.Title
	}
	return result
}

// LoadTrajectoryFromCSV loads trajectory data from a CSV file
func (qm *QueryManager) LoadTrajectoryFromCSV(trajectoryID string) (Trajectory, error) {
	csvPath := filepath.Join(qm.simraFolder, trajectoryID+".csv")

	file, err := os.Open(csvPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open CSV file %s: %v", csvPath, err)
	}
	defer file.Close()

	reader := csv.NewReader(file)

	// Skip header row
	_, err = reader.Read()
	if err != nil {
		return nil, fmt.Errorf("failed to read CSV headers: %v", err)
	}

	var trajectory Trajectory

	// Assume CSV format: timestamp, latitude, longitude (columns 0, 1, 2)
	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("failed to read CSV record: %v", err)
		}

		lat, _ := strconv.ParseFloat(record[1], 64)
		lon, _ := strconv.ParseFloat(record[2], 64)

		point := TrajectoryPoint{
			Timestamp: record[0],
			Latitude:  lat,
			Longitude: lon,
		}

		trajectory = append(trajectory, point)
	}

	return trajectory, nil
}

// ConstructQuery constructs a query by replacing placeholders with actual data
func (qm *QueryManager) ConstructQuery(queryID int, point *TrajectoryPoint, trajectoryID string, trajectoryIDs []string) (string, error) {
	template, err := qm.GetQueryTemplate(queryID)
	if err != nil {
		return "", err
	}

	constructedQuery := template.Query

	// Process each placeholder defined in the template
	for _, placeholder := range template.Placeholders {
		switch placeholder.Type {
		case "POINT":
			if point != nil {
				pointStr := fmt.Sprintf(`POINT("%s" %.6f %.6f)`, point.Timestamp, point.Latitude, point.Longitude)
				constructedQuery = strings.ReplaceAll(constructedQuery, placeholder.Keyword, pointStr)
			} else {
				return "", fmt.Errorf("'point' for 'POINT' query missing")
			}
		case "TRAJECTORY":
			if trajectoryID != "" {
				trajectory, err := qm.LoadTrajectoryFromCSV(trajectoryID)
				if err != nil {
					return "", fmt.Errorf("failed to load trajectory %s: %v", trajectoryID, err)
				}
				trajectoryStr := qm.formatTrajectoryAsLinestring(trajectory)
				constructedQuery = strings.ReplaceAll(constructedQuery, placeholder.Keyword, trajectoryStr)
			} else {
				return "", fmt.Errorf("'trajectoryID' for 'TRAJECTORY' query missing")
			}
		case "TRAJECTORY_LIST":
			if len(trajectoryIDs) >= 1 {
				var tripItems []string

				// Use default template if none provided
				itemTemplate := placeholder.Template
				if itemTemplate == "" {
					return "", fmt.Errorf("'itemTemplate' for 'TRAJECTORY_LIST' query missing")
				}

				for i, trajectoryID := range trajectoryIDs {
					trajectory, err := qm.LoadTrajectoryFromCSV(trajectoryID)
					if err != nil {
						return "", fmt.Errorf("failed to load trajectory %s: %v", trajectoryID, err)
					}

					trajectoryStr := qm.formatTrajectoryAsLinestring(trajectory)

					// Replace template placeholders
					tripItem := strings.ReplaceAll(itemTemplate, "{index}", fmt.Sprintf("%d", i+1))
					tripItem = strings.ReplaceAll(tripItem, "{trajectory}", trajectoryStr)

					tripItems = append(tripItems, tripItem)
				}

				trajectoryListStr := strings.Join(tripItems, ",\n      ")
				constructedQuery = strings.ReplaceAll(constructedQuery, placeholder.Keyword, trajectoryListStr)
			} else {
				return "", fmt.Errorf("'trajectoryIDs' for 'TRAJECTORY_LIST' query missing")
			}
		}
	}

	return constructedQuery, nil
}

// formatTrajectoryAsLinestring converts a trajectory to LINESTRING format
func (qm *QueryManager) formatTrajectoryAsLinestring(trajectory Trajectory) string {
	if len(trajectory) == 0 {
		return "LINESTRING()"
	}

	var points []string
	for _, point := range trajectory {
		pointStr := fmt.Sprintf(`"%s" %.6f %.6f`, point.Timestamp, point.Latitude, point.Longitude)
		points = append(points, pointStr)
	}

	return fmt.Sprintf("LINESTRING(\n      %s\n    )", strings.Join(points, ",\n      "))
}

// Example usage and testing
func ParseTest() {
	// Initialize the query manager
	qm := NewQueryManager("./simra")

	// Load all queries into memory
	err := qm.LoadQueries("queries.yaml")
	if err != nil {
		fmt.Printf("Error loading queries: %v\n", err)
		return
	}

	// List all available queries
	fmt.Println("\nAvailable queries:")
	for id, title := range qm.ListQueries() {
		fmt.Printf("  %d: %s\n", id, title)
	}

	// Example 1: Construct query 1 (point lookup) with a specific point
	point := &TrajectoryPoint{
		Timestamp: "2022-11-16T14:30",
		Latitude:  52.520000,
		Longitude: 13.350000,
	}

	var list []string

	query1, err := qm.ConstructQuery(1, point, "", list)
	if err != nil {
		fmt.Printf("Error constructing query 1: %v\n", err)
	} else {
		fmt.Printf("\n--- Constructed Query 1 ---\n%s\n", query1)
	}

	// Example 2: Construct query 2 (trajectory exposure) with a trajectory
	query2, err := qm.ConstructQuery(2, nil, "trip001", list)
	if err != nil {
		fmt.Printf("Error constructing query 2: %v\n", err)
	} else {
		fmt.Printf("\n--- Constructed Query 2 ---\n%s\n", query2)
	}

	// Example 3: Construct query 3 (duration above threshold) with a trajectory
	query3, err := qm.ConstructQuery(3, nil, "trip002", list)
	if err != nil {
		fmt.Printf("Error constructing query 3: %v\n", err)
	} else {
		fmt.Printf("\n--- Constructed Query 3 ---\n%s\n", query3)
	}

	// Example 4: Construct query 4 (multiple trajectories) using keywords

	list4 := []string{"trip001", "trip002"}

	query4, err := qm.ConstructQuery(4, nil, "trip002", list4)
	if err != nil {
		fmt.Printf("Error constructing query 4: %v\n", err)
	} else {
		fmt.Printf("\n--- Constructed Query 4 ---\n%s\n", query4)
	}

	// Example 5: Construct query 5 (raster-mask intersection) with a trajectory
	query5, err := qm.ConstructQuery(5, nil, "trip001", list)
	if err != nil {
		fmt.Printf("Error constructing query 5: %v\n", err)
	} else {
		fmt.Printf("\n--- Constructed Query 5 ---\n%s\n", query5)
	}
}
