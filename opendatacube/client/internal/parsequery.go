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

type Placeholder struct {
	Type     string `yaml:"type"`
	Keyword  string `yaml:"keyword"`
	Template string `yaml:"template,omitempty"`
}

type QueryItem struct {
	ID           int           `yaml:"id"`
	Title        string        `yaml:"title"`
	Description  string        `yaml:"description"`
	Placeholders []Placeholder `yaml:"placeholders"`
	Query        string        `yaml:"query"`
}

type TrajectoryPoint struct {
	Timestamp string
	Latitude  float64
	Longitude float64
}

type Trajectory []TrajectoryPoint

type QueryManager struct {
	queries     map[int]QueryItem
	simraFolder string
}

func NewQueryManager(simraFolder string) *QueryManager {
	return &QueryManager{
		queries:     make(map[int]QueryItem),
		simraFolder: simraFolder,
	}
}

func (qm *QueryManager) LoadQueries(yamlFile string) error {
	data, err := os.ReadFile(yamlFile)
	if err != nil {
		return fmt.Errorf("failed to read YAML file: %v", err)
	}

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

func (qm *QueryManager) GetQueryTemplate(queryID int) (QueryItem, error) {
	query, exists := qm.queries[queryID]
	if !exists {
		return QueryItem{}, fmt.Errorf("query with ID %d not found", queryID)
	}
	return query, nil
}

func (qm *QueryManager) ListQueries() map[int]string {
	result := make(map[int]string)
	for id, query := range qm.queries {
		result[id] = query.Title
	}
	return result
}

func (qm *QueryManager) LoadTrajectoryFromCSV(trajectoryID string) (Trajectory, error) {
	csvPath := filepath.Join(qm.simraFolder, trajectoryID+".csv")

	file, err := os.Open(csvPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open CSV file %s: %v", csvPath, err)
	}
	defer file.Close()

	reader := csv.NewReader(file)

	_, err = reader.Read()
	if err != nil {
		return nil, fmt.Errorf("failed to read CSV headers: %v", err)
	}

	var trajectory Trajectory

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

func (qm *QueryManager) ConstructQuery(queryID int, trajectoryIDs []string) (string, error) {
	template, err := qm.GetQueryTemplate(queryID)
	if err != nil {
		return "", err
	}

	constructedQuery := template.Query

	for _, placeholder := range template.Placeholders {
		switch placeholder.Type {
		case "TRAJECTORY":
			if len(trajectoryIDs) > 0 || trajectoryIDs[0] != "" {
				trajectory, err := qm.LoadTrajectoryFromCSV(trajectoryIDs[0])
				if err != nil {
					return "", fmt.Errorf("failed to load trajectory %s: %v", trajectoryIDs[0], err)
				}
				trajectoryStr := qm.formatTrajectoryAsJSONArray(trajectory)
				constructedQuery = strings.ReplaceAll(constructedQuery, placeholder.Keyword, trajectoryStr)
			} else {
				return "", fmt.Errorf("'trajectoryID' for 'TRAJECTORY' query missing")
			}
		case "TRAJECTORY_LIST":
			if len(trajectoryIDs) >= 1 {
				var tripItems []string

				itemTemplate := placeholder.Template
				if itemTemplate == "" {
					return "", fmt.Errorf("'itemTemplate' for 'TRAJECTORY_LIST' query missing")
				}

				for _, trajectoryID := range trajectoryIDs {
					trajectory, err := qm.LoadTrajectoryFromCSV(trajectoryID)
					if err != nil {
						return "", fmt.Errorf("failed to load trajectory %s: %v", trajectoryID, err)
					}

					trajectoryStr := qm.formatTrajectoryAsJSONArray(trajectory)

					tripItem := strings.ReplaceAll(itemTemplate, "{trajectory}", trajectoryStr)

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

func (qm *QueryManager) formatTrajectoryAsJSONArray(traj Trajectory) string {
	if len(traj) == 0 {
		return "[]"
	}

	var rows []string
	for _, point := range traj {
		row := fmt.Sprintf(`["%s", %.6f, %.6f]`, point.Timestamp, point.Latitude, point.Longitude)
		rows = append(rows, row)
	}

	return fmt.Sprintf("[\n      %s\n    ]", strings.Join(rows, ",\n      "))
}
