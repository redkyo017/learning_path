package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func get(t *testing.T, h http.Handler, path string) *httptest.ResponseRecorder {
	t.Helper()
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
	return rec
}

func testMux(draining *atomic.Bool, debug bool) http.Handler {
	return newMux(draining, debug, newOrderStore(), "", "")
}

func TestHealth(t *testing.T) {
	rec := get(t, testMux(&atomic.Bool{}, false), "/health")
	if rec.Code != 200 || !strings.Contains(rec.Body.String(), `"service":"order-api"`) {
		t.Fatalf("got %d %s", rec.Code, rec.Body)
	}
}

func TestReadyAndDraining(t *testing.T) {
	var draining atomic.Bool
	h := testMux(&draining, false)
	if rec := get(t, h, "/ready"); rec.Code != 200 || !strings.Contains(rec.Body.String(), "ready") {
		t.Fatalf("ready: got %d %s", rec.Code, rec.Body)
	}
	draining.Store(true)
	if rec := get(t, h, "/ready"); rec.Code != 503 || !strings.Contains(rec.Body.String(), "draining") {
		t.Fatalf("draining: got %d %s", rec.Code, rec.Body)
	}
	if rec := get(t, h, "/health"); rec.Code != 200 {
		t.Fatalf("liveness must stay 200 while draining, got %d", rec.Code)
	}
}

func TestParsePort(t *testing.T) {
	for raw, want := range map[string]string{"": "8080", "9000": "9000", "65535": "65535"} {
		if got, err := parsePort(raw, "8080"); err != nil || got != want {
			t.Errorf("parsePort(%q) = %q, %v; want %q", raw, got, err, want)
		}
	}
	for _, raw := range []string{"abc", "0", "-1", "65536", "80x", "8080 "} {
		if _, err := parsePort(raw, "8080"); err == nil {
			t.Errorf("parsePort(%q) should fail", raw)
		}
	}
}

func TestDebugAllocGating(t *testing.T) {
	if rec := get(t, testMux(&atomic.Bool{}, false), "/debug/alloc?mb=1"); rec.Code != 404 {
		t.Fatalf("disabled: want 404, got %d", rec.Code)
	}
	h := testMux(&atomic.Bool{}, true)
	if rec := get(t, h, "/debug/alloc?mb=1"); rec.Code != 200 || !strings.Contains(rec.Body.String(), `"retained_mb":1`) {
		t.Fatalf("enabled: got %d %s", rec.Code, rec.Body)
	}
	if rec := get(t, h, "/debug/alloc?mb=2"); !strings.Contains(rec.Body.String(), `"allocated_mb":2,"retained_mb":3`) {
		t.Fatalf("cumulative: got %s", rec.Body)
	}
	if rec := get(t, h, "/debug/alloc?mb=x"); rec.Code != 400 {
		t.Fatalf("bad mb: want 400, got %d", rec.Code)
	}
}

func TestHealthcheckExitCodes(t *testing.T) {
	srv := httptest.NewServer(testMux(&atomic.Bool{}, false))
	defer srv.Close()
	port := srv.URL[strings.LastIndex(srv.URL, ":")+1:]
	if healthcheck(port) != 0 {
		t.Fatal("want 0 against live server")
	}
	srv.Close()
	if healthcheck(port) != 1 {
		t.Fatal("want 1 when nothing listens")
	}
}

func TestParseDrainDelay(t *testing.T) {
	for raw, want := range map[string]int{"": 0, "0": 0, "5": 5, "3600": 3600} {
		if got, err := parseDrainDelay(raw); err != nil || got != time.Duration(want)*time.Second {
			t.Errorf("parseDrainDelay(%q) = %v, %v; want %ds", raw, got, err, want)
		}
	}
	for _, raw := range []string{"abc", "-1", "3601", "1.5", "5s"} {
		if _, err := parseDrainDelay(raw); err == nil {
			t.Errorf("parseDrainDelay(%q) should fail", raw)
		}
	}
}
