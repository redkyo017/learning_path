package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
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

type Order struct {
	ID        string    `json:"id"`
	Item      string    `json:"item"`
	Qty       int       `json:"qty"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
}

// OrderStore is a deliberately simple in-memory store (order-api does not use Postgres).
type OrderStore struct {
	mu     sync.RWMutex
	orders map[string]Order
}

func newOrderStore() *OrderStore {
	return &OrderStore{orders: make(map[string]Order)}
}

func (s *OrderStore) Add(o Order) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.orders[o.ID] = o
}

func (s *OrderStore) GetAll() []Order {
	s.mu.RLock()
	defer s.mu.RUnlock()
	list := make([]Order, 0, len(s.orders))
	for _, o := range s.orders {
		list = append(list, o)
	}
	return list
}

func (s *OrderStore) Get(id string) (Order, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	o, found := s.orders[id]
	return o, found
}

func generateID() string {
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

// callDownstream fire-and-forgets a JSON POST; failures are only logged.
func callDownstream(baseURL, path, orderID string, body map[string]interface{}) {
	payload, _ := json.Marshal(body)
	req, err := http.NewRequestWithContext(context.Background(), http.MethodPost, strings.TrimRight(baseURL, "/")+path, bytes.NewBuffer(payload))
	if err != nil {
		log.Printf("[order-api] bad downstream URL %q: %v", baseURL, err)
		return
	}
	req.Header.Set("Content-Type", "application/json")
	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("[order-api] call to %s failed for order %s: %v", path, orderID, err)
		return
	}
	_ = resp.Body.Close()
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
		writeJSON(w, http.StatusOK, `{"status":"ok","service":"order-api"}`)
	})
	mux.HandleFunc("/ready", func(w http.ResponseWriter, r *http.Request) {
		if draining.Load() {
			writeJSON(w, http.StatusServiceUnavailable, `{"status":"draining","service":"order-api"}`)
			return
		}
		writeJSON(w, http.StatusOK, `{"status":"ready","service":"order-api"}`)
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
		log.Printf("order-api listening on port %s", strings.TrimPrefix(server.Addr, ":"))
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("order-api server error: %v", err)
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
		log.Printf("order-api shutdown error: %v", err)
	}
	log.Println("order-api stopped")
}

func newMux(draining *atomic.Bool, debugAlloc bool, store *OrderStore, paymentURL, notificationURL string) *http.ServeMux {
	mux := http.NewServeMux()
	registerPlatform(mux, draining, debugAlloc)

	mux.HandleFunc("/orders", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode(store.GetAll())

		case http.MethodPost:
			var req struct {
				Item string `json:"item"`
				Qty  int    `json:"qty"`
			}
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				http.Error(w, `{"error":"invalid json"}`, http.StatusBadRequest)
				return
			}
			if req.Item == "" || req.Qty <= 0 {
				http.Error(w, `{"error":"item and positive qty required"}`, http.StatusBadRequest)
				return
			}

			order := Order{
				ID:        generateID(),
				Item:      req.Item,
				Qty:       req.Qty,
				Status:    "PENDING",
				CreatedAt: time.Now().UTC(),
			}
			store.Add(order)

			// Fire-and-forget downstream calls
			if paymentURL != "" {
				go callDownstream(paymentURL, "/payments", order.ID, map[string]interface{}{
					"order_id": order.ID,
					"amount":   29.99,
				})
			}
			if notificationURL != "" {
				go callDownstream(notificationURL, "/notify", order.ID, map[string]interface{}{
					"order_id": order.ID,
					"message":  fmt.Sprintf("Order %s registered", order.ID),
				})
			}

			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusCreated)
			_ = json.NewEncoder(w).Encode(order)

		default:
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})

	mux.HandleFunc("/orders/", func(w http.ResponseWriter, r *http.Request) {
		id := strings.TrimPrefix(r.URL.Path, "/orders/")
		if id == "" {
			http.NotFound(w, r)
			return
		}
		order, found := store.Get(id)
		if !found {
			http.Error(w, `{"error":"order not found"}`, http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(order)
	})
	return mux
}

func main() {
	rawPort := os.Getenv("PORT")
	port, err := parsePort(rawPort, "8080")
	if len(os.Args) > 1 && os.Args[1] == "-healthcheck" {
		if err != nil {
			os.Exit(1)
		}
		os.Exit(healthcheck(port))
	}
	if err != nil {
		log.Fatalf("invalid PORT %q: %v", rawPort, err)
	}

	paymentURL := os.Getenv("PAYMENT_SERVICE_URL")
	notificationURL := os.Getenv("NOTIFICATION_SERVICE_URL")
	store := newOrderStore()
	rawDrain := os.Getenv("DRAIN_DELAY_SECONDS")
	drainDelay, err := parseDrainDelay(rawDrain)
	if err != nil {
		log.Fatalf("invalid DRAIN_DELAY_SECONDS %q: %v", rawDrain, err)
	}
	var draining atomic.Bool
	server := &http.Server{
		Addr:         ":" + port,
		Handler:      newMux(&draining, os.Getenv("ENABLE_DEBUG_ALLOC") == "1", store, paymentURL, notificationURL),
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
	}
	run(server, &draining, drainDelay)
}
