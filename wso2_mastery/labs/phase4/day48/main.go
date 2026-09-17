package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"regexp"
	"sort"
	"strings"
	"time"
)

type LogLine struct {
	Timestamp  time.Time `json:"timestamp"`
	Level      string    `json:"level"`
	Service    string    `json:"service"`
	ActivityID string    `json:"activityId"`
	Message    string    `json:"message"`
}

type Trace struct {
	ActivityID string
	Lines      []*LogLine
}

var logLineRE = regexp.MustCompile(`^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},\d+)\]\s+(\w+)\s+\{([^}]+)\}\s+-\s+(.+)$`)
var activityRE = regexp.MustCompile(`\[activityId:([^\]]+)\]`)

func inferService(cls string) string {
	c := strings.ToLower(cls)
	switch {
	case strings.Contains(c, "gateway") || strings.Contains(c, "apimgt.gateway"):
		return "GW"
	case strings.Contains(c, "identity"):
		return "IS"
	case strings.Contains(c, "throttle"):
		return "TM"
	default:
		return "CP"
	}
}

func parseLines(scanner *bufio.Scanner) ([]*LogLine, []string) {
	var result []*LogLine
	var order []string
	seen := make(map[string]bool)
	for scanner.Scan() {
		raw := scanner.Text()
		if strings.HasPrefix(raw, "\t") || strings.HasPrefix(raw, "at ") {
			continue
		}
		m := logLineRE.FindStringSubmatch(raw)
		if m == nil {
			continue
		}
		ts, _ := time.Parse("2006-01-02 15:04:05,000", m[1])
		ll := &LogLine{
			Timestamp: ts, Level: m[2],
			Service: inferService(m[3]), Message: m[4],
		}
		if am := activityRE.FindStringSubmatch(m[4]); am != nil {
			ll.ActivityID = am[1]
			if !seen[ll.ActivityID] {
				seen[ll.ActivityID] = true
				order = append(order, ll.ActivityID)
			}
		}
		result = append(result, ll)
	}
	return result, order
}

func correlate(lines []*LogLine) map[string]*Trace {
	traces := make(map[string]*Trace)
	for _, ll := range lines {
		if ll.ActivityID == "" {
			continue
		}
		if _, ok := traces[ll.ActivityID]; !ok {
			traces[ll.ActivityID] = &Trace{ActivityID: ll.ActivityID}
		}
		traces[ll.ActivityID].Lines = append(traces[ll.ActivityID].Lines, ll)
	}
	return traces
}

func main() {
	filterID := flag.String("id", "", "filter to a single activityId")
	filterSvc := flag.String("service", "", "comma-separated service filter: GW,IS,CP,TM")
	format := flag.String("format", "text", "output format: text or json")
	flag.Parse()

	allowed := make(map[string]bool)
	if *filterSvc != "" {
		for _, s := range strings.Split(*filterSvc, ",") {
			allowed[strings.TrimSpace(strings.ToUpper(s))] = true
		}
	}

	lines, order := parseLines(bufio.NewScanner(os.Stdin))
	traces := correlate(lines)

	if *filterID != "" {
		t, ok := traces[*filterID]
		if !ok {
			fmt.Fprintf(os.Stderr, "no trace found for id %s\n", *filterID)
			os.Exit(0)
		}
		order = []string{*filterID}
		_ = t
	}

	for _, id := range order {
		t := traces[id]
		filtered := t.Lines
		if len(allowed) > 0 {
			var keep []*LogLine
			for _, ll := range filtered {
				if allowed[ll.Service] {
					keep = append(keep, ll)
				}
			}
			filtered = keep
		}
		if len(filtered) == 0 {
			continue
		}
		sort.Slice(filtered, func(i, j int) bool {
			return filtered[i].Timestamp.Before(filtered[j].Timestamp)
		})
		if *format == "json" {
			json.NewEncoder(os.Stdout).Encode(filtered)
			continue
		}
		fmt.Printf("=== Trace: %s (%d lines) ===\n", id, len(filtered))
		for _, ll := range filtered {
			fmt.Printf("  [%s] %-3s %-5s %s\n",
				ll.Timestamp.Format("15:04:05.000"), ll.Service, ll.Level, ll.Message)
		}
		fmt.Println()
	}
}
