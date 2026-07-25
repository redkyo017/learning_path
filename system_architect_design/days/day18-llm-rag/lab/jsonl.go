package main

import (
	"bufio"
	"encoding/json"
	"os"
	"strings"
)

// readJSONL reads a newline-delimited JSON file (one object per line) into a
// slice of T. Blank lines are skipped.
func readJSONL[T any](path string) []T {
	f, err := os.Open(path)
	if err != nil {
		die(err)
	}
	defer f.Close()

	var out []T
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		var v T
		if err := json.Unmarshal([]byte(line), &v); err != nil {
			die(err)
		}
		out = append(out, v)
	}
	if err := sc.Err(); err != nil {
		die(err)
	}
	return out
}
