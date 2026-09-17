package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"regexp"
	"strings"
)

type FailureClass string

const (
	ClassAuthFailed     FailureClass = "AUTH_FAILED"
	ClassSubNotFound    FailureClass = "SUBSCRIPTION_NOT_FOUND"
	ClassThrottled      FailureClass = "THROTTLE_EXCEEDED"
	ClassBackendTimeout FailureClass = "BACKEND_TIMEOUT"
	ClassJWTExpired     FailureClass = "JWT_EXPIRED"
	ClassJWTInvalid     FailureClass = "JWT_INVALID_SIGNATURE"
	ClassEventSyncLag   FailureClass = "EVENT_SYNC_LAG"
)

type FailureRule struct {
	Pattern *regexp.Regexp
	Class   FailureClass
	Action  string
}

var rules = []FailureRule{
	{regexp.MustCompile(`(?i)invalid credentials|900901`), ClassAuthFailed, "Check subscription in CP; verify IS /oauth2/token health"},
	{regexp.MustCompile(`(?i)no valid subscription|subscription not found|900908`), ClassSubNotFound, "Restart GW → triggers /admin/sync re-fetch"},
	{regexp.MustCompile(`(?i)throttle limit exceeded|900800`), ClassThrottled, "Check TM health; check GW→TM SG (9611/9711)"},
	{regexp.MustCompile(`(?i)connection timed out|read timeout`), ClassBackendTimeout, "Check backend ECS task; check SG rules"},
	{regexp.MustCompile(`(?i)jwt expired|token expired|\bexp\b claim`), ClassJWTExpired, "Client re-auths; check NTP on GW/IS containers"},
	{regexp.MustCompile(`(?i)signature verification failed|invalid jwt`), ClassJWTInvalid, "curl https://is.wso2.internal:9443/oauth2/jwks; restart GW"},
	{regexp.MustCompile(`(?i)eventhub.*error|sync lag|event sync.*fail`), ClassEventSyncLag, "Restart GW; check CP /admin/sync; check CP logs"},
}

func classify(line string) (FailureClass, string, bool) {
	for _, r := range rules {
		if r.Pattern.MatchString(line) {
			return r.Class, r.Action, true
		}
	}
	return "", "", false
}

func main() {
	verbose := flag.Bool("verbose", false, "also print unmatched lines with [OK] prefix")
	summary := flag.Bool("summary", false, "print counts per class at end")
	flag.Parse()

	counts := make(map[FailureClass]int)
	scanner := bufio.NewScanner(os.Stdin)
	fmt.Printf("%-30s %-26s %s\n", "LINE (truncated)", "CLASS", "ACTION")
	fmt.Println(strings.Repeat("-", 95))
	for scanner.Scan() {
		line := scanner.Text()
		class, action, matched := classify(line)
		if !matched {
			if *verbose {
				short := line
				if len(short) > 28 {
					short = short[:28] + "…"
				}
				fmt.Printf("%-30s %-26s %s\n", short, "[OK]", "")
			}
			continue
		}
		counts[class]++
		short := line
		if len(short) > 28 {
			short = short[:28] + "…"
		}
		fmt.Printf("%-30s %-26s %s\n", short, class, action)
	}
	if *summary && len(counts) > 0 {
		fmt.Println("\n--- Summary ---")
		for _, r := range rules {
			if n := counts[r.Class]; n > 0 {
				fmt.Printf("  %-26s %d\n", r.Class, n)
			}
		}
	}
}
