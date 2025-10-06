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
func (qm *QueryManager) ConstructQuery(queryID int, trajectoryIDs []string) (string, error) {
	template, err := qm.GetQueryTemplate(queryID)
	if err != nil {
		return "", err
	}

	constructedQuery := template.Query

	// Process each placeholder defined in the template
	for _, placeholder := range template.Placeholders {
		switch placeholder.Type {
		case "TRAJECTORY":
			if len(trajectoryIDs) > 0 || trajectoryIDs[0] != "" {
				trajectory, err := qm.LoadTrajectoryFromCSV(trajectoryIDs[0])
				if err != nil {
					return "", fmt.Errorf("failed to load trajectory %s: %v", trajectoryIDs[0], err)
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
