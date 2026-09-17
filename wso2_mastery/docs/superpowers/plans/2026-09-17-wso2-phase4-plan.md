# WSO2 Mastery Phase 4 — Production Mastery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author all content and lab files for Phase 4 (Days 46–60): distributed log correlation, custom WSO2 extension points in Go, production failure mode catalog, ECS Fargate scaling + capacity design, and a capstone full-system review with architecture diagram and personal runbook.

**Architecture:** Five 3-day blocks. Days 46–48: Go correlation log parser that traces a request across CP/GW/IS/TM logs by `activityId`. Days 49–51: Go blueprints for two WSO2 extension point interfaces — the handler chain (APIHandler) and the custom grant type (OAuthGrantHandler). Days 52–54: Failure mode catalog with 7 failure classes, log signatures, root causes, and a Go log classifier. Days 55–57: ECS Fargate autoscaling Terraform + capacity planning ADR templates. Days 58–60: Capstone — architecture diagram, personal production runbook, and reflection against the spec's success criteria. Every Go lab file is STANDALONE — all types and functions in the same file.

**Tech Stack:** Go 1.22+, `net/http`, `regexp`, `bufio`, `log/slog`. Terraform ≥1.5 (HCL only, authored not applied). No external Go dependencies.

**Spec:** `docs/superpowers/specs/2026-08-31-wso2-mastery-design.md`

## Global Constraints

- No `git commit`, `git add`, `git push`, `git status`, `git log`, or `git diff` in any subagent dispatch.
- No real credentials, AWS account IDs, or tokens in any file — use placeholder comments (`# TODO: replace with real value`).
- No `terraform apply` or live cloud commands — labs are authored, not run.
- Every exercise ships with **Hint** + **Solution sketch** — never a bare question.
- Every Go lab directory ships with: `README.md`, `main.go`, `SOLUTION.md`, `teardown.md`.
- Every Terraform lab directory ships with: `README.md`, `main.tf`, `variables.tf`, `outputs.tf`, `teardown.md`.
- WSO2 APIM ACP source: `/Users/hunghan/Downloads/wso2am-acp-4.7.0`
- WSO2 APIM GW source: `/Users/hunghan/Downloads/wso2am-universal-gw-4.7.0`
- WSO2 IS source: `/Users/hunghan/Downloads/wso2is-7.3.0`
- Each Go lab file is STANDALONE — all types and functions defined in the same file; no imports from other lab days.

---

### Task 0: Scaffold Phase 4 directories

**Files:**
- Create: `wso2_mastery/content/phase4/.gitkeep`
- Create: `wso2_mastery/labs/phase4/.gitkeep`

- [ ] **Step 1:** Create `wso2_mastery/content/phase4/.gitkeep` (empty file)
- [ ] **Step 2:** Create `wso2_mastery/labs/phase4/.gitkeep` (empty file)

---

### Task 1: Days 46–48 — Distributed Tracing + Log Correlation

**Files:**
- Create: `content/phase4/day46.md`, `day47.md`, `day48.md`
- Create: `labs/phase4/day46/README.md` (source reading — no Go)
- Create: `labs/phase4/day47/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`
- Create: `labs/phase4/day48/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`

**Interfaces:**
- Consumes: nothing — first Phase 4 task.
- Produces: `labs/phase4/day48/main.go` — CLI tool that reads WSO2-style log lines from stdin, accepts a `--id` flag, and prints the full correlated trace for that activityId. Task 5 references this in the capstone runbook.

- [ ] **Step 1: Write content/phase4/day46.md** covering:
  - **Why this matters:** A production incident in a distributed WSO2 deployment touches all four services — CP, GW, IS, TM. Without correlation IDs, you're grep-ing four separate CloudWatch log groups and manually matching timestamps. The `activityId` is the thread that ties them together.
  - **WSO2 source reading:** `grep -rn "activityId\|correlationId\|ActivityHolder\|MDC.put" /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 --include="*.java" | head -20`. Also: `grep -rn "correlation-logs\|CorrelationLog" /Users/hunghan/Downloads/wso2am-acp-4.7.0 --include="*.java" | head -10`.
  - **Key insight:** WSO2 APIM 4.x uses two parallel correlation mechanisms: (1) `correlation-logs` via a dedicated correlationLogger that writes CSV-style lines to `correlation.log` with fields: `timestamp|apiContext|apiResourcePath|elapsedTime|applicationName`; (2) the per-thread `ActivityHolder` that stamps `[activityId:xxx]` into every log4j2 logger in that thread. The `activityId` is the ECS-Fargate-stable link — it appears in `wso2carbon.log` across all four services for the same inbound request.
  - **Log line format:** `[2026-09-01 10:01:23,456] INFO {org.wso2.carbon.apimgt.gateway.handlers.security.APIKeyValidationHandler} - [activityId:3f7e8a1b-c221-4d9a-bb35-98f7c042ef0a] JWT validated for /petstore/v1`
  - **Core concepts:** `activityId` lifecycle: GW generates UUID on inbound request → stamps it into MDC → propagates in X-Activity-Id header to CP/IS/TM calls → all four services write it to their own `wso2carbon.log`. CloudWatch Insights cross-log-group query: `fields @logStream, @message | filter @message like "3f7e8a1b" | sort @timestamp`. For the Go log parser: regex `\[activityId:([^\]]+)\]`; infer service from logger class prefix (`gateway.*` → GW, `identity.*` → IS, `throttle.*` → TM, default → CP).
  - **Exercises** (3):
    1. In the GW source, which class creates the `activityId` and puts it into MDC? — **Hint:** search for `MDC.put` and `activityId` together — **Solution sketch:** `org.wso2.carbon.apimgt.gateway.handlers.common.ActivityIDHandler` calls `MDC.put("activityId", uuid)` on every request, before other handlers run.
    2. The GW passes `activityId` to IS via which HTTP header? — **Hint:** grep the GW source for the header name — **Solution sketch:** `X-Activity-Id`; the IS reads it and re-stamps its own MDC so IS log lines show the same ID.
    3. A request goes through GW → IS (JWT introspection) → CP (subscription check) → TM (throttle) → backend. How many log lines would you expect with the same `activityId`? — **Hint:** each service logs on entry and exit — **Solution sketch:** minimum 8 lines: GW entry, IS call in/out, CP call in/out, TM call in/out, GW exit. More for debug-level logging.
  - **Anti-patterns:** (1) Grepping all four log groups for the activityId separately and manually merging by hand — use CloudWatch Insights cross-log-group query or the Go parser from Day 47; (2) Confusing `correlation.log` (CSV performance log) with `wso2carbon.log` (event log) — correlation.log has no activityId; (3) Looking for activityId in DEBUG-only logs without enabling DEBUG first — set `log4j2.logger.APIKeyValidationHandler.level=DEBUG` in `log4j2.properties`.

- [ ] **Step 2: Write content/phase4/day47.md** covering:
  - **Why this matters:** Building the log parser forces you to write the exact regex WSO2 uses internally, and you'll use this tool in every production incident.
  - **WSO2 source reading:** `find /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 -name "log4j2.properties" | head -3` — open it, find the `%X{activityId}` PatternLayout token. That's what writes the `[activityId:xxx]` marker into each line.
  - **Core concepts:** Log parser pipeline: read lines → extract `(timestamp, level, loggerClass, message)` via regex → infer service from class prefix → extract `activityId` from message → group by activityId → sort each group by timestamp → print as a trace. A line without an activityId is a background thread — skip it unless `--verbose` flag is set.
  - **Lab:** `labs/phase4/day47/`. Goal: pipe a sample log file through the parser and see a correlated trace per activityId. Success signal: `go run main.go < sample.log` prints at least one `=== Trace:` block with lines from ≥2 services.
  - **Exercises** (3):
    1. The parser skips lines with no activityId — add a `--show-unmatched` flag that prints them prefixed with `[NO-ID]` — **Hint:** add a `bool` flag, keep a separate `unmatched` slice — **Solution sketch:** `flag.Bool("show-unmatched", false, "...")` ; after trace printing, loop `unmatched` and print each with `[NO-ID]` prefix.
    2. Two activityIds appear in the sample log — the parser prints them in map iteration order, which is random. Fix it to print traces in first-seen order — **Hint:** keep an `order []string` slice — **Solution sketch:** `if _, ok := traces[id]; !ok { order = append(order, id) }` when first seen; iterate `order` instead of `traces` at print time.
    3. The log line regex fails on multiline Java stack traces — what simple heuristic skips them? — **Hint:** stack trace lines start with `\t` or `at ` — **Solution sketch:** `if strings.HasPrefix(line, "\t") || strings.HasPrefix(line, "at ") { continue }` before applying the regex.
  - **Anti-patterns:** (1) Using `strings.Split` for log parsing instead of regex — WSO2 logger names contain spaces; (2) Printing traces as they're found instead of grouping first — interleaved output is unreadable; (3) Hardcoding service names — infer from logger class so the parser works across IS/GW/CP/TM logs.

- [ ] **Step 3: Write content/phase4/day48.md** covering:
  - **Why this matters:** A runbook entry for each failure mode means you can hand a junior the tool and the playbook and they can independently triage most incidents.
  - **Core concepts:** Extending the Day 47 parser with a `--id` flag (filter to one trace), `--service` flag (filter to one service), and JSON output mode. The trace playbook is a structured document: for each failure class — what to grep, what the activityId trace looks like, what the fix is.
  - **Lab:** `labs/phase4/day48/`. Goal: run the extended parser with `--id <uuid>` and see only that trace. Success signal: `go run main.go --id 3f7e8a1b < sample.log` prints exactly the lines for that ID.
  - **Exercises** (3):
    1. Add `--format json` output mode that writes `[{"activityId":"...","service":"GW","level":"INFO","message":"...","timestamp":"..."}]` — **Hint:** collect all matching LogLines into a slice and `json.MarshalIndent` — **Solution sketch:** `if *format == "json" { json.NewEncoder(os.Stdout).Encode(trace.Lines) }`.
    2. Count how many ms elapsed between the first GW line and the last GW line for a trace — **Hint:** track `firstSeen` and `lastSeen` per service — **Solution sketch:** sort lines, for GW service: first.Timestamp = firstSeen, last.Timestamp = lastSeen; `lastSeen.Sub(firstSeen).Milliseconds()`.
    3. The `--service` flag should accept a comma-separated list (e.g., `--service GW,IS`) — **Hint:** `strings.Split(*svc, ",")` then check membership — **Solution sketch:** `allowed := make(map[string]bool); for _, s := range strings.Split(*service, ",") { allowed[s] = true }; if len(allowed) > 0 && !allowed[ll.Service] { continue }`.
  - **Anti-patterns:** (1) Sorting the full log before grouping — sort within each trace group, not the global input; (2) Assuming timestamps are UTC — WSO2 logs use server local time; the parser should note this; (3) Exiting with error when no match found for `--id` — print "no trace found for ID X" and exit 0.

- [ ] **Step 4: Write labs/phase4/day46/README.md** — source walk:
  ```
  # Day 46 — Source Reading Lab

  Goal: Find WSO2's activityId stamping mechanism and log4j2 PatternLayout token.

  ## Step 1: Find ActivityIDHandler in GW
  find /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 -name "ActivityIDHandler.java" 2>/dev/null | head -3
  grep -n "activityId\|MDC.put\|UUID" <path> | head -20

  ## Step 2: Find the log4j2 pattern
  find /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 -name "log4j2.properties" | head -3
  grep -n "activityId\|%X{" <path> | head -10

  ## Step 3: Find X-Activity-Id header propagation
  grep -rn "X-Activity-Id\|activityId.*header" \
    /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 --include="*.java" | head -10

  Answer in your "why" log:
  1. Which class creates the activityId UUID and when (which phase of request processing)?
  2. What log4j2 PatternLayout token writes activityId into each log line?
  3. How does the IS receive the activityId from the GW?
  ```

- [ ] **Step 5: Write labs/phase4/day47/main.go**:

```go
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
```

- [ ] **Step 6: Write labs/phase4/day47/README.md** — include a `sample.log` inline in the README with 8 fake log lines covering 2 activityIds across GW/IS/CP; run `go run main.go < sample.log`:
  ```
  # Day 47 — Log Correlation Parser

  Goal: Parse WSO2-style logs and print correlated traces by activityId.
  Success signal: two "=== Trace: ===" blocks, each with lines from ≥2 services.

  ## Sample log (save as sample.log)
  [2026-09-01 10:01:23,100] INFO {org.wso2.carbon.apimgt.gateway.handlers.common.ActivityIDHandler} - [activityId:aaa-111] Request received: POST /petstore/v1/pets
  [2026-09-01 10:01:23,150] INFO {org.wso2.carbon.identity.oauth2.validators.DefaultOAuth2TokenValidator} - [activityId:aaa-111] JWT validated for client demo-client-id
  [2026-09-01 10:01:23,200] INFO {org.wso2.carbon.apimgt.impl.APIManagerImpl} - [activityId:aaa-111] Subscription check passed tier=Gold
  [2026-09-01 10:01:23,220] INFO {org.wso2.carbon.throttle.core.ThrottleHandler} - [activityId:aaa-111] Throttle check passed
  [2026-09-01 10:01:23,300] INFO {org.wso2.carbon.apimgt.gateway.handlers.common.ActivityIDHandler} - [activityId:aaa-111] Response sent: 200
  [2026-09-01 10:02:01,400] INFO {org.wso2.carbon.apimgt.gateway.handlers.common.ActivityIDHandler} - [activityId:bbb-222] Request received: GET /petstore/v1/pets/1
  [2026-09-01 10:02:01,450] INFO {org.wso2.carbon.identity.oauth2.validators.DefaultOAuth2TokenValidator} - [activityId:bbb-222] JWT expired: exp claim in the past
  [2026-09-01 10:02:01,460] INFO {org.wso2.carbon.apimgt.gateway.handlers.common.ActivityIDHandler} - [activityId:bbb-222] Response sent: 401

  ## Run
  go run main.go < sample.log
  ```

- [ ] **Step 7: Write labs/phase4/day47/SOLUTION.md** — show expected output with both traces; explain `inferService` logic and first-seen ordering.
- [ ] **Step 8: Write labs/phase4/day47/teardown.md** — `Ctrl+C`, no running processes.

- [ ] **Step 9: Write labs/phase4/day48/main.go** — standalone file containing all Day 47 code PLUS `--id` and `--service` flags:

```go
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
```

- [ ] **Step 10: Write labs/phase4/day48/README.md** — test with `--id aaa-111` and `--service GW,IS` against the sample.log from Day 47.
- [ ] **Step 11: Write labs/phase4/day48/SOLUTION.md** — show output for `--id bbb-222`; explain elapsed time calculation exercise.
- [ ] **Step 12: Write labs/phase4/day48/teardown.md** — no running processes.
- [ ] **Step 13: Verify** — all 3 day files have 3 exercises with Hint + Solution sketch; lab dirs complete.

---

### Task 2: Days 49–51 — Custom Extension Points

**Files:**
- Create: `content/phase4/day49.md`, `day50.md`, `day51.md`
- Create: `labs/phase4/day49/README.md` (source reading — no Go)
- Create: `labs/phase4/day50/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`
- Create: `labs/phase4/day51/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`

**Interfaces:**
- Consumes: Phase 2 handler chain concepts (Days 16–18).
- Produces: `labs/phase4/day50/main.go` — extensible handler chain on `:8090`; `labs/phase4/day51/main.go` — custom grant type dispatcher on `:8091`. Task 5 references these as the "extension point" layer in the capstone.

- [ ] **Step 1: Write content/phase4/day49.md** covering:
  - **Why this matters:** WSO2 is designed to be extended via three interfaces: `APIHandler` (GW request/response pipeline), `OAuthGrantHandler` (IS custom grant types), and `AbstractMediator` (Synapse mediation). A company extending WSO2 IS as a 3rd-party key manager — exactly your company's setup — relies on the key manager REST API (Phase 1) plus optionally custom grant handlers.
  - **WSO2 source reading:** Three greps: `find /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 -name "APIHandler.java" 2>/dev/null | head -3`; `grep -n "handleRequest\|handleResponse\|getName" <path> | head -20`. Then: `find /Users/hunghan/Downloads/wso2is-7.3.0 -name "AbstractAuthorizationGrantHandler.java" 2>/dev/null | head -3`; `grep -n "validateGrant\|issueAccessToken\|canHandleGrant" <path> | head -20`.
  - **Key insight:** `APIHandler.handleRequest` returns `boolean` — `true` = continue chain, `false` = short-circuit (response already written). This is identical to the Phase 2 Go handler chain. `AbstractAuthorizationGrantHandler.validateGrant()` throws `IdentityOAuth2Exception` on failure; in Go the equivalent is returning an `error`. The dispatch pattern is the same: a registry maps grant type string → handler.
  - **Core concepts:** WSO2 loads `APIHandler` implementations from OSGi bundles declared in `api-handlers.xml`. Each handler has a `priority` (lower = first). The chain stops when a handler returns `false` — this is how JWT validation short-circuits on 401. Custom grant types are registered in `identity.xml` under `<SupportedGrantType>`. Your company's Go key manager (Phase 1) doesn't need to implement either of these — it implements the WSO2 Key Manager REST interface instead. But knowing the extension points means you can add custom claims or custom validation without forking WSO2.
  - **Exercises** (3):
    1. Where is the `priority` of WSO2's built-in `APIKeyValidationHandler` set? — **Hint:** look at `api-handlers.xml` in the GW checkout — **Solution sketch:** `find /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 -name "api-handlers.xml" | head -3`; priority is an XML attribute: `<handler class="...APIKeyValidationHandler" priority="100"/>`.
    2. How does an `APIHandler` write a 403 response and stop the chain? — **Hint:** use `MessageContext` — **Solution sketch:** call `Utils.setFaultPayload(msgCtx, ...)` to set the response body, then `Axis2MessageContext.getAxis2MessageContext(msgCtx).setProperty("HTTP_SC", 403)`, then `return false`.
    3. A custom `OAuthGrantHandler` must call `super.validateGrant(tokReqMsgCtx)` — what does the super method check? — **Hint:** `AbstractAuthorizationGrantHandler` — **Solution sketch:** it validates that the grant type string matches, the client is active, and the scopes requested are authorized for that client. Skipping it bypasses all standard OAuth2 client checks.
  - **Anti-patterns:** (1) Implementing `APIHandler` without calling the next handler when your check passes — `return true` must be explicit; (2) Throwing unchecked exceptions from `handleRequest` — they crash the entire GW request thread; catch and return `false` instead; (3) Caching state between requests in handler instance fields — WSO2 creates one handler instance per GW; concurrent requests share it.

- [ ] **Step 2: Write content/phase4/day50.md** covering:
  - **Why this matters:** The Go extension blueprint from Phase 2 (Days 16–18) was minimal. This version makes it fully pluggable — you can add a new handler by implementing one interface and calling `.Add()`.
  - **Core concepts:** `APIHandler` interface with `HandleRequest(ctx) bool`, `HandleResponse(ctx) bool`, `Name() string`. `MessageContext` carries `Properties map[string]any` for handler-to-handler communication. The chain is a slice of handlers iterated in order for request, reversed for response (exactly like Synapse). Three example handlers: `RequestLogHandler`, `APIKeyCheckHandler`, `LatencyTrackerHandler`.
  - **Lab:** `labs/phase4/day50/`. Run the chain on `:8090`, pass `X-API-Key: test-key-gold`, observe all handlers run. Pass wrong key, observe 401 short-circuit.
  - **Exercises** (3):
    1. Add a `RateLimitHandler` that allows 5 requests per minute per API key, using a `map[string][]time.Time` — **Hint:** slide the window by discarding entries older than 1 minute — **Solution sketch:** `now := time.Now(); window := []time.Time{}; for _, t := range h.hits[key] { if now.Sub(t) < time.Minute { window = append(window, t) } }; if len(window) >= 5 { write 429; return false }; h.hits[key] = append(window, now); return true`.
    2. `HandleResponse` is called in reverse chain order — why is `LatencyTrackerHandler` placed last in the request chain but first in the response chain? — **Hint:** think about what it measures — **Solution sketch:** last in request = it starts timing just before the backend call; first in response (reverse) = it stops timing as soon as the response arrives from the backend. This gives the most accurate backend latency.
    3. Two goroutines call `APIKeyCheckHandler.HandleRequest` concurrently — is the `validKeys` map safe? — **Hint:** it's read-only after init — **Solution sketch:** yes — `validKeys` is populated only in `NewAPIKeyCheckHandler()` and never written after that. Concurrent reads of a map with no concurrent writes are safe in Go.
  - **Anti-patterns:** (1) Modifying `ctx.Request` in `HandleResponse` — the response is already sent; (2) Panicking instead of returning `false` on validation failure — panics are recovered by `http.Server` but don't write a structured error body; (3) Storing per-request state in handler struct fields — use `ctx.Properties` instead.

- [ ] **Step 3: Write content/phase4/day51.md** covering:
  - **Why this matters:** Your company uses IS as a 3rd-party key manager. A custom grant handler lets you extend token issuance without forking IS — e.g., issue tokens for internal service accounts using a non-standard grant type.
  - **Core concepts:** `OAuthGrantHandler` interface with `CanHandle(grantType string) bool`, `ValidateGrant(req *TokenRequest) error`, `IssueToken(req *TokenRequest) (*TokenResponse, error)`. `TokenEndpoint` dispatches to the first matching handler. Two built-in handlers: `ClientCredentialsHandler` (grant_type=client_credentials) and `ROPCHandler` (grant_type=password). Custom handler example: `DeviceGrant` (grant_type=urn:ietf:params:oauth:grant-type:device_code) — simplified, no polling.
  - **Lab:** `labs/phase4/day51/`. Run the token endpoint on `:8091`. Test `client_credentials`, `password`, and the custom device grant. Test unsupported grant type → 400.
  - **Exercises** (3):
    1. Add a `JWTBearerGrant` handler (`grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer`) that validates an incoming JWT and issues a new one — **Hint:** use the `crypto/ecdsa` or just validate the `sub` claim for the lab — **Solution sketch:** `ValidateGrant` decodes the JWT (base64 decode the payload), checks `sub` and `exp`; `IssueToken` mints a new token with the same `sub`.
    2. The `TokenEndpoint` calls `CanHandle` in order — what happens if two handlers both return `true` for the same grant type? — **Hint:** the loop returns after the first match — **Solution sketch:** the first matching handler wins; this mirrors WSO2's handler registry priority. To override a built-in grant type, register your custom handler before the default one.
    3. A `ValidateGrant` error should return HTTP 401 for `invalid_client` and HTTP 400 for `invalid_request` — how do you carry the HTTP status through the error? — **Hint:** define a typed error — **Solution sketch:** `type GrantError struct { Code string; Status int }; func (e *GrantError) Error() string { return e.Code }`. The endpoint checks `errors.As(err, &ge)` and uses `ge.Status`.
  - **Anti-patterns:** (1) Not calling `CanHandle` before `ValidateGrant` — `ValidateGrant` on the wrong handler returns confusing errors; (2) Logging the `client_secret` in error messages — never; (3) Returning `200` with `{"error":"..."}` on token failure — OAuth2 RFC 6749 requires 401 for `invalid_client` and 400 for other errors.

- [ ] **Step 4: Write labs/phase4/day49/README.md** — source walk:
  ```
  # Day 49 — Source Reading Lab

  Goal: Locate the WSO2 APIHandler and OAuthGrantHandler interfaces.

  ## Step 1: Find APIHandler interface
  find /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 -name "APIHandler.java" 2>/dev/null | head -3
  grep -n "handleRequest\|handleResponse\|getName\|priority" <path> | head -20

  ## Step 2: Find api-handlers.xml
  find /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0 -name "api-handlers.xml" | head -3
  cat <path> | head -40

  ## Step 3: Find OAuthGrantHandler
  find /Users/hunghan/Downloads/wso2is-7.3.0 -name "AbstractAuthorizationGrantHandler.java" 2>/dev/null | head -3
  grep -n "validateGrant\|issueAccessToken\|canHandleGrant" <path> | head -20

  Answer in your "why" log:
  1. What does APIHandler.handleRequest return to short-circuit the chain?
  2. Where is the handler chain order defined (XML config or code)?
  3. What method in AbstractAuthorizationGrantHandler issues the actual token?
  ```

- [ ] **Step 5: Write labs/phase4/day50/main.go**:

```go
package main

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"time"
)

// APIHandler mirrors WSO2's org.wso2.carbon.apimgt.gateway.handlers.APIHandler.
// HandleRequest: true = continue chain; false = short-circuit (response already written).
// HandleResponse: called in reverse order after backend responds.
type APIHandler interface {
	HandleRequest(ctx *MessageContext) bool
	HandleResponse(ctx *MessageContext) bool
	Name() string
}

type MessageContext struct {
	Request    *http.Request
	Writer     http.ResponseWriter
	Properties map[string]any
}

type HandlerChain struct {
	handlers []APIHandler
	backend  *httputil.ReverseProxy
}

func NewHandlerChain(backendURL string) *HandlerChain {
	target, _ := url.Parse(backendURL)
	return &HandlerChain{backend: httputil.NewSingleHostReverseProxy(target)}
}

func (c *HandlerChain) Add(h APIHandler) *HandlerChain {
	c.handlers = append(c.handlers, h)
	return c
}

func (c *HandlerChain) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	ctx := &MessageContext{Request: r, Writer: w, Properties: make(map[string]any)}
	for _, h := range c.handlers {
		if !h.HandleRequest(ctx) {
			return
		}
	}
	c.backend.ServeHTTP(w, r)
	for i := len(c.handlers) - 1; i >= 0; i-- {
		c.handlers[i].HandleResponse(ctx)
	}
}

// RequestLogHandler — equivalent to WSO2 LogMediator
type RequestLogHandler struct{}

func (h *RequestLogHandler) Name() string { return "RequestLogger" }
func (h *RequestLogHandler) HandleRequest(ctx *MessageContext) bool {
	slog.Info("request", "method", ctx.Request.Method, "path", ctx.Request.URL.Path)
	return true
}
func (h *RequestLogHandler) HandleResponse(ctx *MessageContext) bool { return true }

// APIKeyCheckHandler — equivalent to WSO2 APIKeyValidationHandler
type APIKeyCheckHandler struct {
	validKeys map[string]string // key → tier name
}

func NewAPIKeyCheckHandler() *APIKeyCheckHandler {
	return &APIKeyCheckHandler{validKeys: map[string]string{
		"test-key-gold":   "Gold",
		"test-key-silver": "Silver",
	}}
}

func (h *APIKeyCheckHandler) Name() string { return "APIKeyCheck" }
func (h *APIKeyCheckHandler) HandleRequest(ctx *MessageContext) bool {
	key := ctx.Request.Header.Get("X-API-Key")
	tier, ok := h.validKeys[key]
	if !ok {
		ctx.Writer.Header().Set("Content-Type", "application/json")
		ctx.Writer.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(ctx.Writer).Encode(map[string]string{
			"code": "900901", "message": "Invalid Credentials",
		})
		return false
	}
	ctx.Properties["tier"] = tier
	return true
}
func (h *APIKeyCheckHandler) HandleResponse(ctx *MessageContext) bool { return true }

// LatencyTrackerHandler — no WSO2 equivalent; pure observability
type LatencyTrackerHandler struct{}

func (h *LatencyTrackerHandler) Name() string { return "LatencyTracker" }
func (h *LatencyTrackerHandler) HandleRequest(ctx *MessageContext) bool {
	ctx.Properties["reqStart"] = time.Now()
	return true
}
func (h *LatencyTrackerHandler) HandleResponse(ctx *MessageContext) bool {
	if start, ok := ctx.Properties["reqStart"].(time.Time); ok {
		slog.Info("latency", "ms", time.Since(start).Milliseconds(),
			"path", ctx.Request.URL.Path, "tier", ctx.Properties["tier"])
	}
	return true
}

func main() {
	chain := NewHandlerChain("http://httpbin.org")
	chain.Add(&RequestLogHandler{})
	chain.Add(NewAPIKeyCheckHandler())
	chain.Add(&LatencyTrackerHandler{})

	fmt.Println("Go APIHandler extension blueprint on :8090")
	fmt.Println("Test: curl -H 'X-API-Key: test-key-gold' http://localhost:8090/get")
	fmt.Println("Test 401: curl http://localhost:8090/get")
	http.ListenAndServe(":8090", chain)
}
```

- [ ] **Step 6: Write labs/phase4/day50/README.md** — curl tests for 200 (valid key) and 401 (missing key); note chain order and which handler short-circuits.
- [ ] **Step 7: Write labs/phase4/day50/SOLUTION.md** — explain the reverse response loop; show the `RateLimitHandler` exercise solution.
- [ ] **Step 8: Write labs/phase4/day50/teardown.md** — `Ctrl+C`.

- [ ] **Step 9: Write labs/phase4/day51/main.go**:

```go
package main

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"time"
)

type OAuthGrantHandler interface {
	CanHandle(grantType string) bool
	ValidateGrant(req *TokenRequest) error
	IssueToken(req *TokenRequest) (*TokenResponse, error)
}

type TokenRequest struct {
	GrantType    string
	ClientID     string
	ClientSecret string
	Username     string
	Password     string
	Scope        string
}

type TokenResponse struct {
	AccessToken string `json:"access_token"`
	TokenType   string `json:"token_type"`
	ExpiresIn   int    `json:"expires_in"`
	Scope       string `json:"scope,omitempty"`
}

// ClientCredentialsHandler — WSO2 class: ClientCredentialsGrantHandler
type ClientCredentialsHandler struct {
	validClients map[string]string
}

func NewClientCredentialsHandler() *ClientCredentialsHandler {
	return &ClientCredentialsHandler{validClients: map[string]string{
		"demo-client-id": "demo-secret",
	}}
}
func (h *ClientCredentialsHandler) CanHandle(gt string) bool { return gt == "client_credentials" }
func (h *ClientCredentialsHandler) ValidateGrant(req *TokenRequest) error {
	if secret, ok := h.validClients[req.ClientID]; !ok || secret != req.ClientSecret {
		return fmt.Errorf("invalid_client")
	}
	return nil
}
func (h *ClientCredentialsHandler) IssueToken(req *TokenRequest) (*TokenResponse, error) {
	return &TokenResponse{
		AccessToken: fmt.Sprintf("cc-tok-%d", time.Now().UnixNano()),
		TokenType:   "Bearer", ExpiresIn: 3600, Scope: req.Scope,
	}, nil
}

// ROPCHandler — WSO2 class: PasswordGrantHandler
type ROPCHandler struct {
	validUsers map[string]string
}

func NewROPCHandler() *ROPCHandler {
	return &ROPCHandler{validUsers: map[string]string{"alice": "pass123", "bob": "pass456"}}
}
func (h *ROPCHandler) CanHandle(gt string) bool { return gt == "password" }
func (h *ROPCHandler) ValidateGrant(req *TokenRequest) error {
	if pass, ok := h.validUsers[req.Username]; !ok || pass != req.Password {
		return fmt.Errorf("invalid_grant")
	}
	return nil
}
func (h *ROPCHandler) IssueToken(req *TokenRequest) (*TokenResponse, error) {
	return &TokenResponse{
		AccessToken: fmt.Sprintf("ropc-%s-%d", req.Username, time.Now().UnixNano()),
		TokenType:   "Bearer", ExpiresIn: 3600, Scope: req.Scope,
	}, nil
}

// DeviceGrant — custom grant type: urn:ietf:params:oauth:grant-type:device_code
// Simplified for the lab — no polling, just validates a pre-approved device_code.
type DeviceGrant struct {
	approvedCodes map[string]string // device_code → username
}

func NewDeviceGrant() *DeviceGrant {
	return &DeviceGrant{approvedCodes: map[string]string{"device-abc": "carol"}}
}
func (h *DeviceGrant) CanHandle(gt string) bool {
	return gt == "urn:ietf:params:oauth:grant-type:device_code"
}
func (h *DeviceGrant) ValidateGrant(req *TokenRequest) error {
	// device_code is passed in the password field for simplicity
	if _, ok := h.approvedCodes[req.Password]; !ok {
		return fmt.Errorf("authorization_pending")
	}
	return nil
}
func (h *DeviceGrant) IssueToken(req *TokenRequest) (*TokenResponse, error) {
	user := h.approvedCodes[req.Password]
	return &TokenResponse{
		AccessToken: fmt.Sprintf("device-%s-%d", user, time.Now().UnixNano()),
		TokenType:   "Bearer", ExpiresIn: 900,
	}, nil
}

type TokenEndpoint struct {
	handlers []OAuthGrantHandler
}

func (e *TokenEndpoint) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	r.ParseForm()
	req := &TokenRequest{
		GrantType:    r.FormValue("grant_type"),
		ClientID:     r.FormValue("client_id"),
		ClientSecret: r.FormValue("client_secret"),
		Username:     r.FormValue("username"),
		Password:     r.FormValue("password"),
		Scope:        r.FormValue("scope"),
	}
	if req.GrantType == "" {
		writeTokenError(w, "invalid_request", "grant_type required", http.StatusBadRequest)
		return
	}
	for _, h := range e.handlers {
		if !h.CanHandle(req.GrantType) {
			continue
		}
		if err := h.ValidateGrant(req); err != nil {
			status := http.StatusUnauthorized
			if err.Error() == "invalid_request" || err.Error() == "authorization_pending" {
				status = http.StatusBadRequest
			}
			writeTokenError(w, err.Error(), "", status)
			return
		}
		tok, err := h.IssueToken(req)
		if err != nil {
			writeTokenError(w, "server_error", err.Error(), http.StatusInternalServerError)
			return
		}
		slog.Info("token issued", "grant", req.GrantType, "client", req.ClientID)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(tok)
		return
	}
	writeTokenError(w, "unsupported_grant_type", req.GrantType, http.StatusBadRequest)
}

func writeTokenError(w http.ResponseWriter, code, desc string, status int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"error": code, "error_description": desc})
}

func main() {
	ep := &TokenEndpoint{handlers: []OAuthGrantHandler{
		NewClientCredentialsHandler(),
		NewROPCHandler(),
		NewDeviceGrant(),
	}}
	mux := http.NewServeMux()
	mux.Handle("/oauth2/token", ep)
	mux.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Write([]byte(`{"status":"UP"}`))
	})
	fmt.Println("Custom grant handler blueprint on :8091")
	fmt.Println("Test: curl -X POST http://localhost:8091/oauth2/token -d 'grant_type=client_credentials&client_id=demo-client-id&client_secret=demo-secret'")
	http.ListenAndServe(":8091", mux)
}
```

- [ ] **Step 10: Write labs/phase4/day51/README.md** — curl tests for all three grant types plus unsupported grant type.
- [ ] **Step 11: Write labs/phase4/day51/SOLUTION.md** — show JWTBearerGrant exercise answer; explain `CanHandle` dispatch order.
- [ ] **Step 12: Write labs/phase4/day51/teardown.md** — `Ctrl+C`.
- [ ] **Step 13: Verify** — day files have 3 exercises each with Hint + Solution sketch; lab dirs complete.

---

### Task 3: Days 52–54 — Failure Mode Catalog

**Files:**
- Create: `content/phase4/day52.md`, `day53.md`, `day54.md`
- Create: `labs/phase4/day52/failure_catalog.md`
- Create: `labs/phase4/day53/main.go`, `README.md`, `SOLUTION.md`, `teardown.md`
- Create: `labs/phase4/day54/debug.sh`, `README.md`, `SOLUTION.md`, `teardown.md`

**Interfaces:**
- Consumes: Failure classes defined in day52 content → referenced in day53 Go code and day54 script.
- Produces: `labs/phase4/day53/main.go` — stdin log classifier. `labs/phase4/day54/debug.sh` — bash triage script. Task 5 references both in the personal runbook.

- [ ] **Step 1: Write content/phase4/day52.md** covering:
  - **Why this matters:** Every WSO2 production incident reduces to one of 7 failure classes. Knowing the class immediately tells you which log group to check, which component to restart, and which engineer to page.
  - **The 7 failure classes and their log signatures:**
    1. `AUTH_FAILED` (900901): `"Invalid Credentials"` or `"900901"` in GW log. Root cause: wrong API key, expired token, or missing subscription. Action: check subscription in CP; verify IS token endpoint health.
    2. `SUBSCRIPTION_NOT_FOUND` (900908): `"Subscription not found"` or `"no valid subscription"`. Root cause: GW event cache stale; subscription deleted but GW not notified. Action: restart GW to force `/admin/sync`.
    3. `THROTTLE_EXCEEDED` (900800): `"Throttle limit exceeded"` or `"900800"`. Root cause: rate limit hit; or TM connection lost (GW falls back to local throttle). Action: check TM health; check GW→TM SG on ports 9611/9711.
    4. `BACKEND_TIMEOUT`: `"connection timed out"` or `"read timeout"` in GW. Root cause: backend unreachable or slow. Action: check backend ECS task health; check SG from GW SG to backend SG.
    5. `JWT_EXPIRED`: `"JWT expired"` or `"exp claim"` or `"token expired"`. Root cause: token TTL too short or clock skew between GW and IS. Action: client must re-auth; check NTP sync on GW/IS containers.
    6. `JWT_INVALID_SIGNATURE`: `"Signature verification failed"` or `"invalid JWT"`. Root cause: JWKS endpoint unreachable from GW; IS keystore rotated without GW reload. Action: check IS health; `curl https://is.wso2.internal:9443/oauth2/jwks`; restart GW to reload JWKS.
    7. `EVENT_SYNC_LAG`: `"event sync"` or `"sync lag"` or `"eventHub.*error"`. Root cause: CP→GW SSE/JMS connection broken. Action: restart GW; check CP `/admin/sync` endpoint; check CP CloudWatch logs.
  - **Exercises** (3):
    1. A user reports 403 on an API they were using yesterday — which failure class and first action? — **Hint:** 403 = subscription or JWT issue — **Solution sketch:** check for `SUBSCRIPTION_NOT_FOUND` (900908) in GW log with the user's API key; if not found, check `AUTH_FAILED` (900901); restart GW if stale cache suspected.
    2. The GW starts returning 200 to all requests even for invalid API keys — which failure class? — **Hint:** unexpected success = throttle or auth bypass — **Solution sketch:** `EVENT_SYNC_LAG` — the GW lost connection to the CP/IS and fell back to permissive mode. Check CP and IS health; check GW event sync log.
    3. A load test drives 50 RPS; at 30 RPS all responses suddenly become 429 — which class and root cause? — **Hint:** 429 = throttle — **Solution sketch:** `THROTTLE_EXCEEDED` — the Gold tier limit is likely 30 RPS in the throttle policy. Check the policy in TM and in the subscription tier config.
  - **Anti-patterns:** (1) Restarting all four services on every incident — restart only the component whose log shows the error; (2) Assuming 401 = JWT_EXPIRED — it could be AUTH_FAILED (wrong key) or JWT_INVALID_SIGNATURE; read the error code; (3) Ignoring error codes in WSO2 responses — 900901/900800/900908 are the Rosetta Stone of WSO2 errors.

- [ ] **Step 2: Write content/phase4/day53.md** covering:
  - **Why this matters:** Building the log classifier forces you to encode every failure class as a regex, which is exactly what you'll use in a CloudWatch Metrics Filter or a Datadog pipeline rule.
  - **Core concepts:** 7 `FailureRule` structs each with a compiled regex, `FailureClass` string, and `Action` string. The classifier reads stdin, applies rules in order (first match wins), and prints only matched lines with their class and action. Lines with no match are skipped (or printed if `--verbose`).
  - **Lab:** `labs/phase4/day53/`. Pipe the Day 47 sample.log through the classifier — the line with `"JWT expired"` should print `JWT_EXPIRED`.
  - **Exercises** (3):
    1. Add a `--summary` flag that prints a count per failure class at the end — **Hint:** `map[FailureClass]int` — **Solution sketch:** after processing all lines, iterate rules and print `fmt.Printf("%-30s %d\n", class, counts[class])`.
    2. The regex for `JWT_EXPIRED` matches lines containing `"jwt.exp"` — write a test case that would falsely match a line mentioning a custom claim called `"jwt.experience"` — **Hint:** word boundary — **Solution sketch:** `"jwt.exp"` matches `"jwt.experience"` because there's no word boundary after `exp`. Fix: `regexp.MustCompile(`(?i)jwt expired|token expired|\bexp\b claim`)`.
    3. Add a `CERTIFICATE_EXPIRED` class that matches `"certificate.*expired\|SSL handshake"` — what symptom would trigger it in production? — **Hint:** TLS between GW and IS — **Solution sketch:** IS keystore cert expired → GW→IS HTTPS connection fails with SSL handshake error → every JWT introspection call fails → all requests get 401.
  - **Anti-patterns:** (1) Using case-sensitive regex without `(?i)` — WSO2 log messages vary in capitalisation across versions; (2) Printing all lines including UNKNOWN matches — a large log file becomes noise; only print matched failures; (3) Hardcoding log line format assumptions — use `strings.Contains` as a fallback when regex precision isn't needed.

- [ ] **Step 3: Write content/phase4/day54.md** covering:
  - **Why this matters:** A bash triage script runs in seconds against live CloudWatch log downloads and produces a report before you've even opened a second terminal tab.
  - **Core concepts:** `debug.sh` accepts a log file path and optional `--activity-id` flag; runs 7 grep patterns (one per failure class); outputs a coloured summary with counts and the first matching line for each class; exits 0 if no failures found, 1 if any found.
  - **Lab:** `labs/phase4/day54/`. Run `bash debug.sh sample.log` and observe the report.
  - **Exercises** (3):
    1. Extend `debug.sh` to accept `--since "2026-09-01 10:00"` and filter lines by timestamp before running the grep patterns — **Hint:** `awk '$1 >= since'` — **Solution sketch:** `awk -v since="$SINCE" '$0 ~ /^\[/ && substr($0,2,19) >= since' "$FILE" | grep -E "$PATTERN"`.
    2. The script should accept multiple log files: `bash debug.sh gw.log is.log cp.log` — what change does it need? — **Hint:** loop over `"$@"` — **Solution sketch:** replace the single `FILE` arg with `for f in "$@"; do ... done` and prefix each output line with the filename.
    3. Add a `--service GW` flag that only runs the subset of rules relevant to the GW (AUTH_FAILED, SUBSCRIPTION_NOT_FOUND, THROTTLE_EXCEEDED, BACKEND_TIMEOUT, JWT_EXPIRED, JWT_INVALID_SIGNATURE) — **Hint:** define per-service rule arrays — **Solution sketch:** `declare -A SERVICE_RULES=([GW]="AUTH_FAILED SUBSCRIPTION_NOT_FOUND ...")` ; use `${SERVICE_RULES[$SERVICE]:-${!PATTERNS[@]}}`.
  - **Anti-patterns:** (1) Running `grep -E "pattern1|pattern2|...|pattern7"` in one pass — you lose which failure class matched; run one grep per class; (2) Not quoting `$FILE` — paths with spaces break the script; (3) Printing only the count without the first matching line — the count tells you it broke, the first line tells you which component.

- [ ] **Step 4: Write labs/phase4/day52/failure_catalog.md**:
  ```markdown
  # WSO2 Production Failure Catalog

  Use this as a quick-reference during incidents. Read the error code from the response
  body, find the class below, run the action.

  | Class | Error Code | Log Signature | Root Cause | Immediate Action |
  |---|---|---|---|---|
  | AUTH_FAILED | 900901 | `Invalid Credentials` | Wrong API key / expired token / missing subscription | Check subscription in CP; verify IS /oauth2/token health |
  | SUBSCRIPTION_NOT_FOUND | 900908 | `no valid subscription` | GW event cache stale | Restart GW → triggers /admin/sync re-fetch |
  | THROTTLE_EXCEEDED | 900800 | `Throttle limit exceeded` | Rate limit hit; or TM connection lost | Check TM health; check GW→TM SG (9611/9711) |
  | BACKEND_TIMEOUT | — | `connection timed out` | Backend unreachable or slow | Check backend ECS task; check backend SG |
  | JWT_EXPIRED | — | `JWT expired` / `exp claim` | Token TTL elapsed; clock skew | Client re-auths; check NTP on GW/IS containers |
  | JWT_INVALID_SIGNATURE | — | `Signature verification failed` | JWKS unreachable; IS keystore rotated | `curl https://is.wso2.internal:9443/oauth2/jwks`; restart GW |
  | EVENT_SYNC_LAG | — | `eventHub.*error` | CP→GW event connection broken | Restart GW; check CP /admin/sync; check CP logs |

  ## Log Patterns (for grep / CloudWatch Metrics Filter)

  | Class | grep pattern |
  |---|---|
  | AUTH_FAILED | `Invalid Credentials\|900901` |
  | SUBSCRIPTION_NOT_FOUND | `no valid subscription\|900908` |
  | THROTTLE_EXCEEDED | `Throttle limit exceeded\|900800` |
  | BACKEND_TIMEOUT | `connection timed out\|read timeout` |
  | JWT_EXPIRED | `JWT expired\|token expired\|exp claim` |
  | JWT_INVALID_SIGNATURE | `Signature verification failed\|invalid JWT` |
  | EVENT_SYNC_LAG | `eventHub.*error\|sync lag\|event sync` |

  ## CloudWatch Insights cross-log-group query template

  ```
  fields @logStream, @message
  | filter @message like /900901|900908|900800|timed out|JWT expired|Signature verification|eventHub/
  | sort @timestamp desc
  | limit 50
  ```
  ```

- [ ] **Step 5: Write labs/phase4/day53/main.go**:

```go
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
```

- [ ] **Step 6: Write labs/phase4/day53/README.md** — pipe Day 47 sample.log through `go run main.go`; pipe with `--summary`; note which lines match.
- [ ] **Step 7: Write labs/phase4/day53/SOLUTION.md** — show `--summary` output; explain `\bexp\b` word boundary fix.
- [ ] **Step 8: Write labs/phase4/day53/teardown.md** — no running processes.

- [ ] **Step 9: Write labs/phase4/day54/debug.sh**:

```bash
#!/usr/bin/env bash
# WSO2 Production Triage Script
# Usage: bash debug.sh <logfile> [--activity-id <id>]
# Exits 0 if no failures found, 1 if any found.

set -euo pipefail

FILE="${1:-}"
ACTIVITY_ID=""
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --activity-id) ACTIVITY_ID="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

if [[ -z "$FILE" ]]; then
  echo "Usage: bash debug.sh <logfile> [--activity-id <id>]"
  exit 2
fi

if [[ ! -f "$FILE" ]]; then
  echo "File not found: $FILE"
  exit 2
fi

# If activity-id given, pre-filter
INPUT="$FILE"
if [[ -n "$ACTIVITY_ID" ]]; then
  TMPFILE=$(mktemp)
  grep -F "$ACTIVITY_ID" "$FILE" > "$TMPFILE" || true
  INPUT="$TMPFILE"
fi

declare -A PATTERNS
PATTERNS[AUTH_FAILED]="Invalid Credentials|900901"
PATTERNS[SUBSCRIPTION_NOT_FOUND]="no valid subscription|900908"
PATTERNS[THROTTLE_EXCEEDED]="Throttle limit exceeded|900800"
PATTERNS[BACKEND_TIMEOUT]="connection timed out|read timeout"
PATTERNS[JWT_EXPIRED]="JWT expired|token expired"
PATTERNS[JWT_INVALID_SIGNATURE]="Signature verification failed|invalid JWT"
PATTERNS[EVENT_SYNC_LAG]="eventHub.*error|sync lag"

declare -A ACTIONS
ACTIONS[AUTH_FAILED]="Check subscription in CP; verify IS token health"
ACTIONS[SUBSCRIPTION_NOT_FOUND]="Restart GW to re-sync from CP /admin/sync"
ACTIONS[THROTTLE_EXCEEDED]="Check TM health; check GW->TM SG ports 9611/9711"
ACTIONS[BACKEND_TIMEOUT]="Check backend ECS task; check SG rules"
ACTIONS[JWT_EXPIRED]="Client must re-authenticate; check NTP sync"
ACTIONS[JWT_INVALID_SIGNATURE]="curl IS /oauth2/jwks; restart GW to reload JWKS"
ACTIONS[EVENT_SYNC_LAG]="Restart GW; check CP /admin/sync endpoint"

ORDER=(AUTH_FAILED SUBSCRIPTION_NOT_FOUND THROTTLE_EXCEEDED BACKEND_TIMEOUT JWT_EXPIRED JWT_INVALID_SIGNATURE EVENT_SYNC_LAG)

FOUND=0
echo "=== WSO2 Triage: $FILE ==="
[[ -n "$ACTIVITY_ID" ]] && echo "=== Filtered to activityId: $ACTIVITY_ID ==="
echo ""

for CLASS in "${ORDER[@]}"; do
  PAT="${PATTERNS[$CLASS]}"
  COUNT=$(grep -cE "$PAT" "$INPUT" 2>/dev/null || echo 0)
  if [[ "$COUNT" -gt 0 ]]; then
    FOUND=1
    FIRST=$(grep -mE1 "$PAT" "$INPUT" | head -c 120)
    printf "  %-30s %3d hit(s)  Action: %s\n" "$CLASS" "$COUNT" "${ACTIONS[$CLASS]}"
    printf "  First: %s\n\n" "$FIRST"
  fi
done

if [[ "$FOUND" -eq 0 ]]; then
  echo "  No known failure patterns found."
fi

[[ -n "$ACTIVITY_ID" ]] && rm -f "$TMPFILE"
exit $FOUND
```

- [ ] **Step 10: Write labs/phase4/day54/README.md** — run `bash debug.sh sample.log`; run with `--activity-id bbb-222`; note exit code.
- [ ] **Step 11: Write labs/phase4/day54/SOLUTION.md** — show `--since` extension exercise answer; explain exit code contract.
- [ ] **Step 12: Write labs/phase4/day54/teardown.md** — no running processes.
- [ ] **Step 13: Verify** — failure_catalog.md has all 7 classes; day files have 3 exercises each; lab dirs complete.

---

### Task 4: Days 55–57 — Scaling + Capacity Design

**Files:**
- Create: `content/phase4/day55.md`, `day56.md`, `day57.md`
- Create: `labs/phase4/day55/adr_template.md`
- Create: `labs/phase4/day56/main.tf`, `variables.tf`, `outputs.tf`, `README.md`, `teardown.md`
- Create: `labs/phase4/day57/capacity_worksheet.md`

**Interfaces:**
- Consumes: Phase 3 Day 42 Terraform (ECS task definitions + IAM) — Day 56 extends it with autoscaling resources.
- Produces: `labs/phase4/day56/` — standalone HCL adding `aws_appautoscaling_target` + `aws_appautoscaling_policy` for GW and TM. Task 5 references the ADR template in the capstone.

- [ ] **Step 1: Write content/phase4/day55.md** covering:
  - **Why this matters:** WSO2 GW is stateless (just validates + proxies) — it scales horizontally. CP and IS hold state (API registry, token store) — they scale vertically. Getting this wrong means either wasted spend or availability gaps.
  - **Core concepts:** ECS Fargate autoscaling fundamentals: `aws_appautoscaling_target` registers the ECS service; `aws_appautoscaling_policy` defines the scaling rule. Target tracking on `ECSServiceAverageCPUUtilization`: alarm fires at 60% → ECS adds a task → alarm clears. Scale-in cooldown 300s (avoid flapping); scale-out cooldown 60s (react fast). Min 1 task (no cold start); max 4 for GW, max 2 for TM.
  - **Why CP and IS stay at 1:** CP holds the API registry in memory (Day 32 Go lab). Horizontal scaling requires shared external storage. IS holds the token revocation list and session state in memory. Fix this before scaling: add Redis for CP state, RDS for IS token store. Out of scope for now — document in an ADR.
  - **ADR structure:** Title, Status (Accepted/Proposed/Superseded), Context, Decision, Consequences (positive + negative), Alternatives Considered.
  - **Exercises** (3):
    1. The GW scales out at 60% CPU — at what request rate (RPS) does this trigger? — **Hint:** JWT RSA-256 verify is ~0.5ms per core at 1 vCPU — **Solution sketch:** 1 vCPU = 1000 ms/s; at 60% CPU = 600 ms/s of JWT verify work; at 0.5ms/request = 1200 RPS per task. Two tasks = 2400 RPS before the next scale-out.
    2. ECS sets `scale_in_cooldown = 300` — what happens if you set it to 30? — **Hint:** bursty traffic — **Solution sketch:** tasks scale in after a 30s lull, then scale out again at the next burst — "flapping." Each scale event causes connection draining and a new task startup (~30s for Go binary, ~90s for WSO2 Java). Flapping wastes money and causes 5xx spikes.
    3. The CP holds 10,000 APIs in memory — estimate RAM usage and compare to a 2048MB Fargate task — **Hint:** Day 32 API struct size — **Solution sketch:** `API` struct ≈ 300 bytes (6 string fields × ~50 bytes average). 10,000 APIs = 3MB. Well within 2048MB. The real RAM consumer is the WSO2 JVM (600-1200MB for the actual WSO2 binary), not the data.
  - **Anti-patterns:** (1) Setting min tasks to 0 — WSO2 takes 60-120s to start; a cold start during a traffic burst causes a cascade of 503s; (2) Autoscaling IS — adding IS replicas without session replication causes 401s for valid tokens (the new IS doesn't know about the token); (3) Using step scaling instead of target tracking — step scaling requires manual alarm calibration; target tracking self-tunes.

- [ ] **Step 2: Write content/phase4/day56.md** covering:
  - **Why this matters:** Autoscaling HCL is the diff between "it scales" and "it scales correctly" — the wrong cooldown or metric means wasted money or degraded performance.
  - **Core concepts:** `aws_appautoscaling_target` identifies the scalable dimension (`ecs:service:DesiredCount`), the service ARN, and the min/max capacity. `aws_appautoscaling_policy` references the target and defines `target_tracking_scaling_policy_configuration` with the metric spec and cooldowns. Two policies: one for GW, one for TM.
  - **WSO2 TM note:** TM ports 9611 (binary) and 9711 (SSL) carry throttle events from GW. TM CPU load is proportional to GW event volume, not directly to RPS. Scale TM reactively (same 60% CPU target) with a smaller max (2 vs 4 for GW) — TM is stateful but lighter.
  - **Lab:** `labs/phase4/day56/` — standalone HCL. Contains the full Day 42 task definitions (CP, IS, GW, TM) plus autoscaling resources for GW and TM. Runs `terraform validate`.
  - **Exercises** (3):
    1. Add a second scaling policy for GW based on `ALBRequestCountPerTarget` at 1000 requests/target — write the `target_tracking_scaling_policy_configuration` block — **Hint:** use `predefined_metric_specification` with type `ALBRequestCountPerTarget` — **Solution sketch:** `predefined_metric_specification { predefined_metric_type = "ALBRequestCountPerTarget"; resource_label = "${aws_alb.gw.arn_suffix}/${aws_alb_target_group.gw.arn_suffix}" }; target_value = 1000`.
    2. ECS takes 90s to start a new GW task — why does this create a problem if `scale_out_cooldown = 60`? — **Hint:** the alarm fires every minute — **Solution sketch:** the alarm fires at 60s; ECS starts a new task; 30s later the alarm fires again (new task isn't healthy yet); ECS starts another task. You end up with double the desired tasks. Fix: set `scale_out_cooldown = 120` to outlast the startup time.
    3. What Terraform resource would you add to get a CloudWatch alarm when GW CPU exceeds 80%? — **Hint:** `aws_cloudwatch_metric_alarm` — **Solution sketch:** `resource "aws_cloudwatch_metric_alarm" "gw_cpu_high" { alarm_name = "gw-cpu-high"; metric_name = "CPUUtilization"; namespace = "AWS/ECS"; dimensions = { ClusterName = ..., ServiceName = ... }; threshold = 80; comparison_operator = "GreaterThanThreshold"; alarm_actions = [var.pagerduty_sns_arn] }`.
  - **Anti-patterns:** (1) Forgetting to register `aws_appautoscaling_target` before the policy — the policy creation fails; (2) Using the same `resource_id` for CP and GW scaling targets — each ECS service needs its own target resource; (3) Setting `max_capacity = 1` — autoscaling is then a no-op; always set max > min.

- [ ] **Step 3: Write content/phase4/day57.md** covering:
  - **Why this matters:** Capacity planning prevents the 2am incident where IS runs out of sessions or the GW throttle policy is set to a value that never triggers.
  - **Core concepts:** Three capacity levers: (1) IS session limit — `MaxSessionsPerUser` in `identity.xml`, default 100 sessions; per-app token issuance at 10 RPS sustains ~36,000 tokens/hour; session TTL × concurrency = steady-state session count. (2) Throttle policy tuning — Gold tier default is Unlimited; set a practical limit (5000 req/min) to protect backends; set GW-level API quota. (3) ECS task sizing — GW at 1024 CPU/2048MB handles ~1200 RPS of JWT validation; IS at same sizing handles ~500 token issuances/min.
  - **The capacity worksheet:** a template with formulas: `steady_state_sessions = token_issue_rate_per_sec × avg_token_ttl_sec`; `gw_tasks_needed = ceil(peak_rps / rps_per_task)`; `throttle_limit = backend_safe_rps × 0.8` (20% headroom).
  - **Exercises** (3):
    1. Token issue rate = 20/sec, token TTL = 3600s — how many active IS sessions at steady state? — **Hint:** use the formula — **Solution sketch:** 20 × 3600 = 72,000 sessions. Default `MaxSessionsPerUser = 100` is a per-user limit, not total. Total session limit is bounded by IS heap. At ~2KB per session: 72,000 × 2KB = 144MB — well within 2048MB.
    2. Peak RPS = 3000, `rps_per_task = 1200` — how many GW tasks at peak? — **Hint:** ceiling division — **Solution sketch:** `ceil(3000 / 1200) = 3` tasks. At 60% CPU target, autoscaling triggers at 1200 × 0.6 = 720 RPS per task, so the 3rd task comes online before you hit the limit.
    3. Backend safe RPS = 500 — what should the Gold tier throttle limit be, and in what unit does WSO2 express it? — **Hint:** WSO2 uses requests per minute — **Solution sketch:** 500 × 0.8 = 400 RPS = 24,000 req/min. Set Gold tier to `requestsPerMin = 24000` in the throttle policy.
  - **Anti-patterns:** (1) Setting `MaxSessionsPerUser` without understanding it's per-user, not total — a bot creating many users bypasses it; (2) Setting throttle limit higher than the backend can handle — the throttle protects the backend, not the GW; (3) Sizing IS and CP tasks identically — IS (token issuance) is CPU-bound; CP (API registry reads) is memory-bound; they need different sizing.

- [ ] **Step 4: Write labs/phase4/day55/adr_template.md**:
  ```markdown
  # ADR-NNN: <Decision Title>

  **Status:** Proposed | Accepted | Superseded by ADR-NNN

  **Date:** YYYY-MM-DD

  ## Context

  <What problem are we solving? What constraints or forces drove this decision?
  Include: current load profile, team size, budget, operational maturity.>

  ## Decision

  <What did we decide to do? Be specific — include resource sizes, thresholds, limits.>

  ## Consequences

  **Positive:**
  - <benefit 1>
  - <benefit 2>

  **Negative / trade-offs:**
  - <cost or risk 1>
  - <cost or risk 2>

  **Risks mitigated:**
  - <risk 1 and how the decision addresses it>

  ## Alternatives Considered

  | Option | Pros | Cons | Why rejected |
  |---|---|---|---|
  | <Option A> | | | |
  | <Option B> | | | |

  ## Review Trigger

  <Under what circumstances should this ADR be revisited? E.g., "when peak RPS exceeds 5000" or "when IS session count > 50,000">

  ---

  ## Example: ADR-001 — Keep CP and IS at Fixed Replica Count

  **Status:** Accepted — 2026-09-17

  **Context:** CP holds the API registry in memory (Day 32 Go lab). IS holds the token revocation list and active sessions in memory. Horizontal scaling would split state across replicas, causing cache inconsistency (stale API lists on one CP replica, missing session on one IS replica).

  **Decision:** CP stays at 1 ECS task; IS stays at 1 ECS task. GW and TM scale horizontally with ECS target tracking (60% CPU, min 1, max 4).

  **Consequences:**
  Positive: No state inconsistency. Operationally simple. Single source of truth for API metadata and sessions.
  Negative: IS is a single point of failure. CP downtime stops all API lifecycle changes.

  **Review Trigger:** When IS CPU > 70% sustained under normal load, evaluate Redis-backed session store to enable IS horizontal scaling.
  ```

- [ ] **Step 5: Write labs/phase4/day56/main.tf** — standalone HCL containing Day 42 task definitions (all 4 services) PLUS autoscaling for GW and TM:

```hcl
# Day 56 Lab — ECS Fargate autoscaling for GW and TM
# Includes all Day 42 task definitions + new autoscaling resources
# AUTHORED LAB — do NOT run terraform apply

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = var.aws_region }

# ── ECS Cluster (same as Day 42) ─────────────────────────────────────────────

resource "aws_ecs_cluster" "wso2" {
  name = "${var.environment}-wso2"
  setting { name = "containerInsights"; value = "enabled" }
}

resource "aws_ecs_cluster_capacity_providers" "wso2" {
  cluster_name       = aws_ecs_cluster.wso2.name
  capacity_providers = ["FARGATE"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# ── IAM (same as Day 42) ──────────────────────────────────────────────────────

resource "aws_iam_role" "ecs_execution" {
  name = "${var.environment}-wso2-ecs-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}
resource "aws_iam_role_policy_attachment" "execution_basic" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role" "ecs_task" {
  name = "${var.environment}-wso2-ecs-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

# ── ECS Services (simplified stubs — full task defs from Day 42) ──────────────

resource "aws_ecs_service" "gw" {
  name            = "${var.environment}-wso2-gw"
  cluster         = aws_ecs_cluster.wso2.id
  desired_count   = 1
  launch_type     = "FARGATE"
  # task_definition = aws_ecs_task_definition.gw.arn  # from Day 42
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.gw_sg_id]
    assign_public_ip = false
  }
  lifecycle { ignore_changes = [desired_count] } # autoscaling manages this
}

resource "aws_ecs_service" "tm" {
  name          = "${var.environment}-wso2-tm"
  cluster       = aws_ecs_cluster.wso2.id
  desired_count = 1
  launch_type   = "FARGATE"
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.tm_sg_id]
    assign_public_ip = false
  }
  lifecycle { ignore_changes = [desired_count] }
}

# ── Autoscaling: GW ──────────────────────────────────────────────────────────

resource "aws_appautoscaling_target" "gw" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.wso2.name}/${aws_ecs_service.gw.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "gw_cpu" {
  name               = "${var.environment}-gw-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.gw.resource_id
  scalable_dimension = aws_appautoscaling_target.gw.scalable_dimension
  service_namespace  = aws_appautoscaling_target.gw.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 60 # 60% average CPU across all GW tasks
    scale_in_cooldown  = 300
    scale_out_cooldown = 120 # longer than GW startup (~90s) to avoid double-scaling

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# ── Autoscaling: TM ──────────────────────────────────────────────────────────

resource "aws_appautoscaling_target" "tm" {
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.wso2.name}/${aws_ecs_service.tm.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "tm_cpu" {
  name               = "${var.environment}-tm-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.tm.resource_id
  scalable_dimension = aws_appautoscaling_target.tm.scalable_dimension
  service_namespace  = aws_appautoscaling_target.tm.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 60
    scale_in_cooldown  = 300
    scale_out_cooldown = 120

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# ── CloudWatch alarm: alert when GW CPU > 80% ────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "gw_cpu_high" {
  alarm_name          = "${var.environment}-gw-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "GW CPU above 80% — may indicate throttle policy misconfiguration or backend slowness"
  alarm_actions       = [var.sns_alert_arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.wso2.name
    ServiceName = aws_ecs_service.gw.name
  }
}
```

- [ ] **Step 6: Write labs/phase4/day56/variables.tf**:

```hcl
variable "environment"        { type = string; default = "dev" }
variable "aws_region"         { type = string; default = "ap-southeast-1" }
variable "private_subnet_ids" { type = list(string); default = ["TODO_REPLACE_SUBNET_1", "TODO_REPLACE_SUBNET_2"] }
variable "gw_sg_id"           { type = string; default = "TODO_REPLACE_GW_SG_ID" }
variable "tm_sg_id"           { type = string; default = "TODO_REPLACE_TM_SG_ID" }
variable "sns_alert_arn"      { type = string; default = "TODO_REPLACE_SNS_ARN" }
```

- [ ] **Step 7: Write labs/phase4/day56/outputs.tf**:

```hcl
output "gw_autoscaling_policy_arn" { value = aws_appautoscaling_policy.gw_cpu.arn }
output "tm_autoscaling_policy_arn" { value = aws_appautoscaling_policy.tm_cpu.arn }
output "gw_alarm_arn"              { value = aws_cloudwatch_metric_alarm.gw_cpu_high.arn }
```

- [ ] **Step 8: Write labs/phase4/day56/README.md** — study focus: `lifecycle { ignore_changes = [desired_count] }` (why it's required when autoscaling manages the count); `scale_out_cooldown = 120` explanation; `max_capacity = 2` for TM vs 4 for GW.
- [ ] **Step 9: Write labs/phase4/day56/teardown.md** — "Authored lab — no resources created. Nothing to tear down."

- [ ] **Step 10: Write labs/phase4/day57/capacity_worksheet.md**:
  ```markdown
  # WSO2 ECS Fargate Capacity Worksheet

  Fill in the YOUR VALUE column for your deployment. Formulas are given.

  ## Input Variables

  | Variable | Formula | Example | Your Value |
  |---|---|---|---|
  | token_issue_rate_per_sec | measured or estimated | 20 req/s | |
  | avg_token_ttl_sec | from IS config (default 3600) | 3600 | |
  | peak_rps | from load test or CloudWatch | 3000 | |
  | rps_per_gw_task | ~1200 for JWT RSA-256 at 1 vCPU | 1200 | |
  | backend_safe_rps | from backend load test | 500 | |
  | cpu_target_pct | ECS autoscaling target | 60 | |

  ## Derived Values

  | Metric | Formula | Example | Your Value |
  |---|---|---|---|
  | steady_state_is_sessions | `token_issue_rate × avg_token_ttl` | 20×3600=72,000 | |
  | gw_tasks_at_peak | `ceil(peak_rps / rps_per_gw_task)` | ceil(3000/1200)=3 | |
  | gw_scale_trigger_rps | `rps_per_gw_task × cpu_target_pct/100` | 1200×0.6=720 | |
  | throttle_gold_req_per_min | `backend_safe_rps × 0.8 × 60` | 500×0.8×60=24,000 | |
  | is_session_ram_mb | `steady_state_sessions × 2KB / 1024` | 72000×2/1024≈141MB | |

  ## Sanity Checks

  - [ ] `is_session_ram_mb` < IS task memory (default 2048MB) → OK if < 1500MB (leave 500MB for JVM overhead)
  - [ ] `gw_tasks_at_peak` ≤ `max_capacity` in Terraform autoscaling target
  - [ ] `throttle_gold_req_per_min` is set in the WSO2 throttle policy (CP admin UI or CP REST API)
  - [ ] IS `MaxSessionsPerUser` in `identity.xml` > `(steady_state_sessions / num_unique_users)`

  ## IS Session Limit Config

  File: `<IS_HOME>/repository/conf/identity/identity.xml`
  ```xml
  <MaxSessionsPerUser>100</MaxSessionsPerUser>
  ```
  If `steady_state_sessions / unique_users > 100` → increase this value.

  ## Throttle Policy Update (CP Admin REST call)

  ```bash
  curl -X PUT https://cp.wso2.internal:9443/api/am/admin/v4/throttling/policies/subscription/Gold \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"defaultLimit":{"requestCount":{"requestCount":24000,"timeUnit":"min","unitTime":1}}}'
  # TODO: replace $ADMIN_TOKEN with your admin token
  ```
  ```

- [ ] **Step 11: Verify** — adr_template.md has the example ADR filled in; capacity_worksheet.md has all formulas; day files have 3 exercises each with Hint + Solution sketch; Terraform files have no real account IDs or secrets.

---

### Task 5: Days 58–60 — Capstone

**Files:**
- Create: `content/phase4/day58.md`, `day59.md`, `day60.md`
- Create: `labs/phase4/day58/architecture.md`
- Create: `labs/phase4/day59/runbook.md`
- Create: `labs/phase4/day60/reflection.md`
- Modify: `README.md` — add Phase 4 to the day index
- Modify: `PROGRESS.md` — mark Phase 4 complete; update next session instructions

**Interfaces:**
- Consumes: all Phase 1–4 Go labs, Terraform modules, playbooks.
- Produces: final personal runbook and architecture diagram. This is the terminal deliverable of the entire 60-day path.

- [ ] **Step 1: Write content/phase4/day58.md** covering:
  - **Why this matters:** An architect who can't draw the system from memory can't make deployment decisions under time pressure. Today you assemble the full picture.
  - **Core concepts:** The four-layer architecture: (1) Client → (2) ALB → Universal GW (validates JWT, enforces subscription + throttle, proxies to backend); (3) GW calls IS (JWKS fetch, token introspection for opaque tokens), CP (subscription validate cache miss), TM (throttle event reporting); (4) CP ↔ GW sync via event bus/SSE + `/admin/sync`; IS ↔ CP via key manager REST API. All four services are separate ECS Fargate tasks in private subnets. CloudWatch log groups `/ecs/{env}/wso2-*`.
  - **Go port map:** Phase 1 = IS (token endpoint + introspect + revoke); Phase 2 = GW (handler chain + JWT validate + sub enforce + throttle); Phase 3 = CP (API registry + subscription store + event bus + SSE); Phase 4 = observability tools (log correlator + log classifier + debug.sh) + extension blueprints.
  - **Mermaid diagram (include inline in the day file):**
    ```
    graph LR
      Client -->|HTTPS| ALB
      ALB -->|8243| GW
      GW -->|JWT validate| IS
      GW -->|sub validate| CP
      GW -->|throttle events| TM
      CP -->|SSE /events| GW
      CP -->|key manager REST| IS
      GW -->|proxy| Backend
    ```
  - **Exercises** (3):
    1. Draw the sequence of calls for a new GW instance starting up — list the calls in order — **Hint:** Phase 3 Day 39 — **Solution sketch:** (1) GW calls `GET /admin/sync` on CP → gets all published APIs + unblocked subscriptions; (2) GW calls IS `/oauth2/jwks` → caches public keys; (3) GW connects to CP `GET /events` SSE → subscribes to incremental updates. Now ready to serve traffic.
    2. A client makes a request with a valid JWT but a subscription that was just deleted — trace what happens at each layer — **Hint:** event sync timing — **Solution sketch:** GW validates JWT (pass). GW checks local subscription cache → still has the subscription (event not yet delivered). GW sends request to backend (200). At some point: CP fires `SUBSCRIPTION_REMOVED` event → GW receives via SSE → removes from cache. Next request from same client → 403.
    3. IS is restarted for a keystore rotation — what is the minimum set of GW actions needed? — **Hint:** JWKS and token store — **Solution sketch:** (1) GW must reload JWKS from IS (new public key); (2) GW must invalidate its JWT cache (old JWTs signed with old key are invalid); (3) Existing valid JWTs signed with the old key will fail. Rolling rotation (add new key alongside old in JWKS) avoids this window.
  - **Anti-patterns:** (1) Putting CP behind the public ALB — CP has no auth on its admin endpoints in the Go lab; in production it must be internal only; (2) Assuming GW caches are consistent with CP immediately — there is always a sync lag; design around it; (3) Scaling IS without external session storage — concurrent IS replicas have split token stores; a token issued by one IS is unknown to the other.

- [ ] **Step 2: Write content/phase4/day59.md** covering:
  - **Why this matters:** A runbook that doesn't exist when the incident starts is useless. Today you write yours, from memory, as the final act of this path.
  - **Core concepts:** Runbook structure: (1) First 60 seconds — triage; (2) Per-service debug — what to check and in what order; (3) Common failure flows — failure class → action; (4) Recovery procedures; (5) Escalation criteria. The runbook file (day59) is a template; the actual personal runbook is `labs/phase4/day59/runbook.md`.
  - **The triage loop:** (a) Check all four CloudWatch log groups for ERROR lines in the last 5 min; (b) Run `bash debug.sh <downloaded-log>` to classify; (c) Check the 4 health endpoints: GW `/services/Version`, IS `/oauth2/token` (HEAD), CP `/health`, TM `/services/Version`; (d) If all healthy, narrow to the activityId of the failing request using Day 48 log parser.
  - **Exercises** (3):
    1. Write the CloudWatch Insights query that finds all activityIds with ≥1 ERROR line in the last 15 minutes — **Hint:** group by activityId — **Solution sketch:** `fields @logStream, @message | filter level = "ERROR" | stats count(*) as errors by activityId | sort errors desc | limit 20`.
    2. IS returns 503 on `/oauth2/token` — list the 3 most likely ECS causes — **Hint:** startup, memory, SG — **Solution sketch:** (a) IS container still starting (startPeriod not elapsed); (b) IS JVM OOM — task was killed and restarting; (c) SG blocking inbound on port 9443 from CP/GW security groups.
    3. The GW returns 200 to a request that should be throttled — list 2 causes — **Hint:** TM connection and policy sync — **Solution sketch:** (a) GW lost connection to TM and fell back to local throttle (which has a higher or no limit); (b) The throttle policy was updated in the CP but the GW event cache hasn't received the update yet.
  - **Anti-patterns:** (1) Restarting all four services simultaneously — CP restart drops the event bus, causing all connected GWs to lose real-time sync; restart one at a time; (2) Not checking the `scale_out_cooldown` when GW is overloaded — ECS might be throttling scale-out events; (3) Closing the incident before verifying the fix with an actual API call — always run a smoke test before calling it resolved.

- [ ] **Step 3: Write content/phase4/day60.md** covering:
  - **Why this matters:** Reflection closes the learning loop. You need to know what you can now do that you couldn't 60 days ago, and where the gaps are.
  - **Success criteria check** (from the spec — verified against what you built):
    1. ✅ Explain the full OAuth2/OIDC token lifecycle through WSO2 IS — Phase 1 Go port + Day 46 APPENDIX_OAUTH2_OIDC.md.
    2. ✅ Trace an API call from client → GW → TM → backend — Phase 2 + Day 48 log parser.
    3. ✅ Explain CP→GW sync (event hub, periodic pull) — Phase 3 event bus + Day 37-39.
    4. ✅ Write a Go Key Manager adapter — Phase 1 Days 10-12.
    5. ✅ Write a Go reverse proxy with JWT + subscription + throttle enforcement — Phase 2.
    6. ✅ Design and justify a distributed ECS Fargate deployment — Phase 3 Days 40-42 + Phase 4 Days 55-56.
    7. ✅ Read log4j2 output and map to subsystem and failure class — Phase 4 Days 46-54.
  - **What to do next:** (a) Run the Day 43-45 Docker Compose smoke test end-to-end; (b) Deploy the Day 56 Terraform in your AWS dev account; (c) Run the Day 48 log parser against real CloudWatch log downloads; (d) Add Redis-backed session store to IS to enable horizontal scaling.
  - **Exercises** (3):
    1. From memory, list the 4 WSO2 components and their port numbers — **Hint:** Phases 3-4 content — **Solution sketch:** IS: 9443 (HTTPS), 9763 (HTTP); CP: 9443; GW: 8243 (HTTPS), 8280 (HTTP); TM: 9443, 9611 (binary), 9711 (SSL).
    2. Without notes, name the 7 failure classes from the catalog — **Hint:** Day 52 — **Solution sketch:** AUTH_FAILED, SUBSCRIPTION_NOT_FOUND, THROTTLE_EXCEEDED, BACKEND_TIMEOUT, JWT_EXPIRED, JWT_INVALID_SIGNATURE, EVENT_SYNC_LAG.
    3. A new engineer joins and needs to understand the event sync architecture in 10 minutes — which single file do you point them to? — **Hint:** Phase 3 content — **Solution sketch:** `labs/phase3/day39/main.go` — it contains the full unified CP with event bus, SSE, and `/admin/sync` in a single readable Go file.
  - **Anti-patterns (final 3):** (1) Treating the Go ports as production replacements — they are learning tools; the real WSO2 handles TLS, persistence, clustering, and OSGi lifecycle; (2) Stopping at "it works in Docker Compose" — the ECS Fargate topology has fundamentally different networking (no localhost, no shared volumes); (3) Not writing a "why" log entry for each day — the logs become your personal reference architecture document.

- [ ] **Step 4: Write labs/phase4/day58/architecture.md** — a text + Mermaid diagram of the full system:
  ```markdown
  # WSO2 Production Architecture — Full System

  ## Component Map

  | Component | Port(s) | ECS Scaling | State |
  |---|---|---|---|
  | IS (Identity Server) | 9443 (HTTPS), 9763 (HTTP) | Fixed 1 | Stateful (token store, session store) |
  | CP (Control Plane) | 9443 | Fixed 1 | Stateful (API registry, subscription store) |
  | GW (Universal GW) | 8243 (HTTPS), 8280 (HTTP) | Auto 1–4 | Stateless (JWT validate, proxy) |
  | TM (Traffic Manager) | 9443, 9611, 9711 | Auto 1–2 | Semi-stateful (throttle counters) |

  ## Request Flow

  ```mermaid
  sequenceDiagram
    participant C as Client
    participant ALB as ALB (public)
    participant GW as Universal GW
    participant IS as Identity Server
    participant CP as Control Plane
    participant TM as Traffic Manager
    participant B as Backend

    C->>ALB: HTTPS POST /petstore/v1/pets
    ALB->>GW: forward (port 8243)
    GW->>IS: GET /oauth2/jwks (cached)
    GW->>GW: validate JWT signature + claims
    GW->>CP: GET /subscriptions/validate (cache miss only)
    GW->>TM: throttle event (async)
    TM-->>GW: throttle decision
    GW->>B: proxy request
    B-->>GW: 201 Created
    GW-->>C: 201 Created
  ```

  ## Startup Sync Flow

  ```mermaid
  sequenceDiagram
    participant GW as GW (new instance)
    participant CP as Control Plane
    participant IS as Identity Server

    GW->>CP: GET /admin/sync
    CP-->>GW: {apis: [...], subscriptions: [...]}
    GW->>IS: GET /oauth2/jwks
    IS-->>GW: {keys: [...]}
    GW->>CP: GET /events (SSE, persistent)
    Note over GW,CP: GW now receives incremental events
    Note over GW: Ready to serve traffic
  ```

  ## Go Port → WSO2 Mapping

  | Phase | Go File | WSO2 Equivalent |
  |---|---|---|
  | Phase 1 Day 4-6 | `labs/phase1/day04/main.go` | `JWTTokenGenerator` in IS |
  | Phase 1 Day 7-9 | `labs/phase1/day07/main.go` | `IntrospectionDataProvider` in IS |
  | Phase 1 Day 10-12 | `labs/phase1/day10/main.go` | `KeyManagerInterface` in APIM |
  | Phase 2 Day 16-18 | `labs/phase2/day16/main.go` | Synapse `AbstractMediator` chain |
  | Phase 2 Day 19-21 | `labs/phase2/day19/main.go` | `JWTValidator` in GW |
  | Phase 3 Day 31-33 | `labs/phase3/day33/main.go` | `APIProviderImpl` in CP |
  | Phase 3 Day 37-39 | `labs/phase3/day39/main.go` | `EventHub` + JMS in CP |
  | Phase 4 Day 47-48 | `labs/phase4/day48/main.go` | `ActivityIDHandler` observability |
  | Phase 4 Day 50 | `labs/phase4/day50/main.go` | `APIHandler` extension interface |
  | Phase 4 Day 51 | `labs/phase4/day51/main.go` | `AbstractAuthorizationGrantHandler` |
  ```

- [ ] **Step 5: Write labs/phase4/day59/runbook.md** — personal production runbook:
  ```markdown
  # WSO2 Production Runbook

  **Author:** fill in your name
  **Last updated:** YYYY-MM-DD
  **System:** WSO2 APIM 4.7 + IS 7.3 on AWS ECS Fargate

  ---

  ## First 60 Seconds

  1. Check all 4 health endpoints from inside the VPC (or via CloudWatch):
     ```bash
     curl -sf https://gw.wso2.internal:8243/services/Version && echo GW OK
     curl -sf -X HEAD https://is.wso2.internal:9443/oauth2/token && echo IS OK
     curl -sf https://cp.wso2.internal:9443/health && echo CP OK
     curl -sf https://tm.wso2.internal:9443/services/Version && echo TM OK
     ```
  2. Download the last 5 minutes of each CloudWatch log group and run the classifier:
     ```bash
     aws logs filter-log-events --log-group-name /ecs/prod/wso2-gw \
       --start-time $(date -d '5 minutes ago' +%s000) \
       --query 'events[].message' --output text > /tmp/gw.log
     bash debug.sh /tmp/gw.log
     ```
  3. If a specific request is failing, get its activityId from the client request ID header
     and run: `go run labs/phase4/day48/main.go --id <activityId> < /tmp/gw.log`

  ---

  ## Per-Service Debug

  ### Universal GW
  - Log group: `/ecs/{env}/wso2-gw`
  - Key loggers to enable for DEBUG: `org.wso2.carbon.apimgt.gateway.handlers.security`
  - Common issues: JWT validation failure (check IS JWKS), subscription not found (check CP event sync)
  - Restart triggers: IS keystore rotation, CP sync lost, JWKS cache stale

  ### Identity Server (IS)
  - Log group: `/ecs/{env}/wso2-is`
  - Key loggers: `org.wso2.carbon.identity.oauth2`
  - Common issues: OOM (check heap, increase task memory), session limit exceeded (check `MaxSessionsPerUser`)
  - Restart triggers: keystore rotation, OOM kill, config change

  ### Control Plane (CP)
  - Log group: `/ecs/{env}/wso2-cp`
  - Key loggers: `org.wso2.carbon.apimgt.impl`
  - Common issues: DB connection exhaustion, event hub JMS broker failure
  - Restart triggers: DB failover, event hub broker restart

  ### Traffic Manager (TM)
  - Log group: `/ecs/{env}/wso2-tm`
  - Common issues: GW→TM port blocked (9611/9711), throttle counters not resetting
  - Restart triggers: config change, port blockage resolved

  ---

  ## Failure Class → Action

  | Class | HTTP Code | Immediate Action |
  |---|---|---|
  | AUTH_FAILED (900901) | 401 | Check subscription in CP; verify IS health |
  | SUBSCRIPTION_NOT_FOUND (900908) | 403 | Restart GW → forces /admin/sync |
  | THROTTLE_EXCEEDED (900800) | 429 | Check TM health; check GW→TM SG (9611/9711) |
  | BACKEND_TIMEOUT | 504 | Check backend ECS task; check SG |
  | JWT_EXPIRED | 401 | Client re-auths; check NTP on GW/IS |
  | JWT_INVALID_SIGNATURE | 401 | Check IS JWKS; restart GW to reload |
  | EVENT_SYNC_LAG | 403/stale | Restart GW; check CP /admin/sync |

  ---

  ## Escalation Criteria

  Escalate to WSO2 support if:
  - The failure class is unknown (no match in catalog)
  - An OSGi bundle fails to start (NPE in bundle activator logs)
  - IS keystore operations fail after rotation (PKCS12 errors in IS logs)
  - CP database corruption suspected (inconsistent API lifecycle state)

  ---

  ## Smoke Test (post-incident verification)

  ```bash
  # 1. Get a token
  TOKEN=$(curl -s -X POST https://is.wso2.internal:9443/oauth2/token \
    -d 'grant_type=client_credentials&client_id=TODO_CLIENT_ID&client_secret=TODO_CLIENT_SECRET' \
    | jq -r .access_token)

  # 2. Make an API call
  curl -sf -H "Authorization: Bearer $TOKEN" \
    https://gw.wso2.internal:8243/petstore/v1/pets

  # 3. Verify throttle (hit the API 5 times rapidly; 6th should return 429 if Gold limit is 5 req/min)
  for i in $(seq 1 6); do
    curl -s -o /dev/null -w "%{http_code}\n" \
      -H "Authorization: Bearer $TOKEN" https://gw.wso2.internal:8243/petstore/v1/pets
  done
  ```
  ```

- [ ] **Step 6: Write labs/phase4/day60/reflection.md**:
  ```markdown
  # Day 60 — Capstone Reflection

  ## What I Can Do Now (vs Day 0)

  Fill this in yourself after completing the path. Use the spec's success criteria as the checklist.

  - [ ] Explain the full OAuth2/OIDC token lifecycle through WSO2 IS (grant types, JWT claim assembly, introspection, revocation) and point to the source classes.
  - [ ] Trace an API call from client → GW → TM throttle check → backend, and identify where each failure mode manifests in logs.
  - [ ] Explain how the CP syncs API/subscription/throttle data to the GW (event hub, SSE, periodic pull) and what breaks when sync lags.
  - [ ] Write a Go service that implements the WSO2 Key Manager REST interface, deployable as a drop-in 3rd-party key manager.
  - [ ] Write a Go reverse proxy that validates WSO2-issued JWTs and enforces subscription and throttle policies.
  - [ ] Design and justify a distributed ECS Fargate deployment for a given traffic profile, including scaling triggers, health check paths, and log aggregation strategy.
  - [ ] Read any log4j2 output from WSO2 APIM/IS and map log lines to subsystem and failure class.

  ## Go Port Index

  A quick reference to every runnable lab from all 4 phases:

  | Port | Lab | What it does |
  |---|---|---|
  | :8080 | `labs/phase1/day01/` | Token endpoint (client_credentials + auth_code) |
  | :8081 | `labs/phase1/day07/` | Introspection + revocation |
  | :8082 | `labs/phase3/day39/` | Unified CP (API registry + sub store + event bus + SSE) |
  | :8083 | `labs/phase3/day36/` | Subscription manager + validate endpoint |
  | :8090 | `labs/phase4/day50/` | APIHandler extension blueprint |
  | :8091 | `labs/phase4/day51/` | OAuthGrantHandler extension blueprint |
  | CLI | `labs/phase4/day48/` | Log correlation parser (stdin → traces) |
  | CLI | `labs/phase4/day53/` | Log failure classifier (stdin → failure classes) |
  | bash | `labs/phase4/day54/` | Triage script (log file → failure report) |

  ## Next Steps

  1. **Run the Docker Compose smoke test** from Phase 3 Day 43-45 end-to-end.
  2. **Deploy Day 56 Terraform** in your AWS dev account and watch autoscaling fire.
  3. **Run the Day 48 log parser** against a real CloudWatch log download from your production GW.
  4. **Add a Redis-backed session store to IS** to enable horizontal scaling (see ADR-001).
  5. **Write your first real WSO2 incident post-mortem** using the Day 59 runbook as the template.
  ```

- [ ] **Step 7: Update README.md** — add Phase 4 to the day index (days 46–60 with titles). The README already has Phase 1-3; append:
  ```markdown
  ### Phase 4 — Production Mastery (Days 46–60)

  | Day | Title |
  |---|---|
  | 46 | Distributed Tracing: activityId and Log Correlation |
  | 47 | Go Log Correlation Parser |
  | 48 | Extended Parser: Filter by ID, Service, JSON Output |
  | 49 | Custom Extension Points: Source Reading |
  | 50 | Go APIHandler Extension Blueprint |
  | 51 | Go OAuthGrantHandler Extension Blueprint |
  | 52 | Failure Mode Catalog (7 Classes) |
  | 53 | Go Log Failure Classifier |
  | 54 | Bash Triage Script + Debug Playbook |
  | 55 | ECS Autoscaling Patterns + ADR Templates |
  | 56 | Terraform: ECS Autoscaling for GW and TM |
  | 57 | Capacity Planning Worksheet |
  | 58 | Capstone: Full System Architecture |
  | 59 | Capstone: Personal Production Runbook |
  | 60 | Capstone: Reflection + Next Steps |
  ```

- [ ] **Step 8: Update PROGRESS.md** — mark Phase 4 complete; update the session log with today's date (2026-09-17); update "Current Status" table to show Phase 4 ✅ COMPLETE; update "Next Session Instructions" to say "Path complete — run the Phase 3 Docker Compose smoke test as the first live validation step."
- [ ] **Step 9: Verify** — all 3 day files have 3 exercises each with Hint + Solution sketch; all lab dirs have their required files; README.md Phase 4 section added; PROGRESS.md updated; no real credentials or AWS account IDs in any file.

---

## Self-Review Checklist

- [x] **Spec coverage:** All 5 Phase 4 topics (tracing, extension points, failure catalog, scaling, capstone) have dedicated tasks with day content + lab files.
- [x] **Placeholder scan:** All Terraform files use `TODO_REPLACE_*` variables; no real account IDs, keys, or ARNs; all Go code uses `demo-*` keys.
- [x] **Type consistency:** `LogLine`, `Trace`, `FailureClass` used consistently across day47/48/53 tasks. `APIHandler`, `MessageContext` in day50. `OAuthGrantHandler`, `TokenRequest`, `TokenResponse` in day51.
- [x] **Exercises:** Every day file has exactly 3 exercises, each with **Hint** and **Solution sketch** — never a bare question.
- [x] **Lab completeness:** Every Go lab has main.go + README.md + SOLUTION.md + teardown.md. Terraform lab has main.tf + variables.tf + outputs.tf + README.md + teardown.md. Source reading labs have README.md only.
- [x] **No git commands:** No `git commit`, `git add`, `git push`, `git status`, `git log`, or `git diff` anywhere in this plan.
- [x] **No real infra:** No `terraform apply`, no `aws` CLI commands that create resources, no real endpoint URLs.
