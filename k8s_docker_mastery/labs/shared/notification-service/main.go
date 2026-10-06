package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
)

type NotificationRequest struct {
	OrderID string `json:"order_id"`
	Message string `json:"message"`
}

type NotificationResponse struct {
	Status string    `json:"status"`
	SentAt time.Time `json:"sent_at"`
}

// parsePort validates the PORT env value; empty falls back to def.
func parsePort(raw, def string) (string, error) {
	if raw == "" {
		return def, nil
	}
	n, err := strconv.Atoi(raw)
	if err != nil {
		return "", fmt.Errorf("not a number: %w", err)
	}
	if n < 1 || n > 65535 {
		return "", fmt.Errorf("out of range 1-65535")
	}
	return strconv.Itoa(n), nil
}

// parseDrainDelay validates DRAIN_DELAY_SECONDS (whole seconds, 0-3600); empty means 0.
func parseDrainDelay(raw string) (time.Duration, error) {
	if raw == "" {
		return 0, nil
	}
	n, err := strconv.Atoi(raw)
	if err != nil {
		return 0, fmt.Errorf("not a number: %w", err)
	}
	if n < 0 || n > 3600 {
		return 0, fmt.Errorf("out of range 0-3600")
	}
	return time.Duration(n) * time.Second, nil
}

// healthcheck backs `server -healthcheck` (Docker HEALTHCHECK / compose): exit code 0 iff /health is 200.
func healthcheck(port string) int {
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get("http://127.0.0.1:" + port + "/health")
	if err != nil {
		return 1
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}

func writeJSON(w http.ResponseWriter, code int, body string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_, _ = w.Write([]byte(body))
}

// registerPlatform adds the endpoints every service shares:
//
//	/health  liveness: 200 while the process runs
//	/ready   readiness: 503 once draining is set (SIGTERM received)
//	/debug/alloc?mb=N  only when debugAlloc is true; for OOM demos
func registerPlatform(mux *http.ServeMux, draining *atomic.Bool, debugAlloc bool) {
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, `{"status":"ok","service":"notification-service"}`)
	})
	mux.HandleFunc("/ready", func(w http.ResponseWriter, r *http.Request) {
		if draining.Load() {
			writeJSON(w, http.StatusServiceUnavailable, `{"status":"draining","service":"notification-service"}`)
			return
		}
		writeJSON(w, http.StatusOK, `{"status":"ready","service":"notification-service"}`)
	})
	if debugAlloc {
		mux.HandleFunc("/debug/alloc", allocHandler)
	}
}

var (
	allocMu  sync.Mutex
	retained [][]byte
	retainMB int
)

// allocHandler allocates mb MiB, writes every page so it is resident, and keeps it referenced (cumulative).
func allocHandler(w http.ResponseWriter, r *http.Request) {
	mb, err := strconv.Atoi(r.URL.Query().Get("mb"))
	if err != nil || mb < 1 {
		writeJSON(w, http.StatusBadRequest, `{"error":"mb must be a positive integer"}`)
		return
	}
	buf := make([]byte, mb<<20)
	for i := 0; i < len(buf); i += 4096 {
		buf[i] = 1
	}
	allocMu.Lock()
	retained = append(retained, buf)
	retainMB += mb
	total := retainMB
	allocMu.Unlock()
	writeJSON(w, http.StatusOK, fmt.Sprintf(`{"allocated_mb":%d,"retained_mb":%d}`, mb, total))
}

// run serves until SIGTERM/SIGINT, flips readiness, waits drainDelay, then shuts down (20s timeout) and returns.
func run(server *http.Server, draining *atomic.Bool, drainDelay time.Duration) {
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)

	go func() {
		log.Printf("notification-service listening on port %s", strings.TrimPrefix(server.Addr, ":"))
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("notification-service server error: %v", err)
		}
	}()

	<-stop
	draining.Store(true)
	log.Println("SIGTERM received, draining")
	// Keep serving while /ready reports 503, so endpoint removal can propagate before connections close.
	time.Sleep(drainDelay)
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	if err := server.Shutdown(ctx); err != nil {
		log.Printf("notification-service shutdown error: %v", err)
	}
	log.Println("notification-service stopped")
}

func newMux(draining *atomic.Bool, debugAlloc bool) *http.ServeMux {
	mux := http.NewServeMux()
	registerPlatform(mux, draining, debugAlloc)

	mux.HandleFunc("/notify", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req NotificationRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error":"invalid json"}`, http.StatusBadRequest)
			return
		}

		log.Printf("[notification-service] dispatching notification for order %s: %s", req.OrderID, req.Message)

		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(NotificationResponse{
			Status: "SENT",
			SentAt: time.Now().UTC(),
		})
	})
	return mux
}

func main() {
	rawPort := os.Getenv("PORT")
	port, err := parsePort(rawPort, "8082")
	if len(os.Args) > 1 && os.Args[1] == "-healthcheck" {
		if err != nil {
			os.Exit(1)
		}
		os.Exit(healthcheck(port))
	}
	if err != nil {
		log.Fatalf("invalid PORT %q: %v", rawPort, err)
	}

	rawDrain := os.Getenv("DRAIN_DELAY_SECONDS")
	drainDelay, err := parseDrainDelay(rawDrain)
	if err != nil {
		log.Fatalf("invalid DRAIN_DELAY_SECONDS %q: %v", rawDrain, err)
	}
	var draining atomic.Bool
	server := &http.Server{
		Addr:         ":" + port,
		Handler:      newMux(&draining, os.Getenv("ENABLE_DEBUG_ALLOC") == "1"),
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
	}
	run(server, &draining, drainDelay)
}
