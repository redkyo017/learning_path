package main

import (
	"bufio"
	"fmt"
	"os"
	"regexp"
	"sort"
	"strings"
	"time"
)

type LogLine struct {
	Timestamp  time.Time
	Level      string
	Service    string
	ActivityID string
	Message    string
	Raw        string
}

type Trace struct {
	ActivityID string
	Lines      []*LogLine
}

// logLineRE matches WSO2 log4j2 default layout:
// [2006-01-02 15:04:05,000] LEVEL {loggerClass} - message
var logLineRE = regexp.MustCompile(`^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},\d+)\]\s+(\w+)\s+\{([^}]+)\}\s+-\s+(.+)$`)
var activityRE = regexp.MustCompile(`\[activityId:([^\]]+)\]`)

func inferService(loggerClass string) string {
	cls := strings.ToLower(loggerClass)
	switch {
	case strings.Contains(cls, "gateway") || strings.Contains(cls, "apimgt.gateway"):
		return "GW"
	case strings.Contains(cls, "identity") || strings.Contains(cls, "wso2.carbon.identity"):
		return "IS"
	case strings.Contains(cls, "throttle"):
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
		// skip Java stack trace continuation lines
		if strings.HasPrefix(raw, "\t") || strings.HasPrefix(raw, "at ") {
			continue
		}
		m := logLineRE.FindStringSubmatch(raw)
		if m == nil {
			continue
		}
		ts, _ := time.Parse("2006-01-02 15:04:05,000", m[1])
		ll := &LogLine{
			Timestamp: ts,
			Level:     m[2],
			Service:   inferService(m[3]),
			Message:   m[4],
			Raw:       raw,
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

func printTrace(t *Trace) {
	sort.Slice(t.Lines, func(i, j int) bool {
		return t.Lines[i].Timestamp.Before(t.Lines[j].Timestamp)
	})
	fmt.Printf("=== Trace: %s (%d lines) ===\n", t.ActivityID, len(t.Lines))
	for _, ll := range t.Lines {
		fmt.Printf("  [%s] %-3s %-5s %s\n",
			ll.Timestamp.Format("15:04:05.000"), ll.Service, ll.Level, ll.Message)
	}
	fmt.Println()
}

func main() {
	lines, order := parseLines(bufio.NewScanner(os.Stdin))
	traces := correlate(lines)
	if len(traces) == 0 {
		fmt.Fprintln(os.Stderr, "no correlated traces found — check that logs contain [activityId:...] patterns")
		os.Exit(1)
	}
	for _, id := range order {
		printTrace(traces[id])
	}
}
