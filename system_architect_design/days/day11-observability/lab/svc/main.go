// svc is an OpenTelemetry-instrumented HTTP service for the Day 11 lab. Run two
// copies (A and B); A calls B. Each service:
//
//   - exports TRACES to Jaeger via OTLP/HTTP (localhost:4318),
//   - propagates the W3C trace context A -> B (so one trace spans both hops),
//   - exposes RED metrics at /metrics for Prometheus to scrape:
//     http_requests_total{route,method,status}          (Rate + Errors)
//     http_request_duration_seconds{route,method}       (Duration histogram)
//
// Endpoints:
//
//	GET /work?ms=50[&fail=0.2]  -> sleeps ms (optionally 500s ~fail fraction)
//	GET /call?ms=50             -> (service A) calls UPSTREAM/work?ms=..., propagating context
//	GET /metrics                -> Prometheus exposition
//
// Env: NAME (service.name, default "svc"), PORT (8080),
//
//	UPSTREAM (for A, e.g. http://localhost:8081  OR the Toxiproxy port),
//	OTEL_ENDPOINT (host:port of the OTLP/HTTP collector, default localhost:4318).
//
// FIRST TIME (needs internet ONCE to fetch modules):
//
//	cd svc && go mod tidy && go build ./...
//
// Run:
//
//	NAME=B PORT=8081 go run .
//	NAME=A PORT=8080 UPSTREAM=http://localhost:8081 go run .
//	curl "localhost:8080/call?ms=50"     # creates a 2-span trace A->B
package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
)

// ---- RED metrics ----------------------------------------------------------
var (
	reqTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "http_requests_total",
		Help: "Total HTTP requests (Rate + Errors, by status).",
	}, []string{"route", "method", "status"})

	reqDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "http_request_duration_seconds",
		Help:    "HTTP request duration (Duration).",
		Buckets: prometheus.DefBuckets, // .005 .. 10s; good enough to see injected latency
	}, []string{"route", "method"})
)

// statusRecorder captures the response code so the RED middleware can label by it.
type statusRecorder struct {
	http.ResponseWriter
	code int
}

func (s *statusRecorder) WriteHeader(c int) { s.code = c; s.ResponseWriter.WriteHeader(c) }

// redMiddleware records RATE, ERRORS (via status), and DURATION for every request.
// NOTE: route is the low-cardinality path template — never put user/order IDs here
// (that is the cardinality trap from content/day11.md). High-cardinality context
// belongs on the span attributes below.
func redMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, code: 200}
		next.ServeHTTP(rec, r)
		route := r.URL.Path
		reqDuration.WithLabelValues(route, r.Method).Observe(time.Since(start).Seconds())
		reqTotal.WithLabelValues(route, r.Method, strconv.Itoa(rec.code)).Inc()
	})
}

func main() {
	name := env("NAME", "svc")
	port := env("PORT", "8080")
	upstream := os.Getenv("UPSTREAM")
	otlpEndpoint := env("OTEL_ENDPOINT", "localhost:4318")

	ctx := context.Background()
	shutdown := initTracing(ctx, name, otlpEndpoint)
	defer shutdown(ctx)

	tracer := otel.Tracer(name)

	app := http.NewServeMux()

	// /work simulates latency; a child span carries the (high-cardinality) detail.
	app.HandleFunc("/work", func(w http.ResponseWriter, r *http.Request) {
		ms, _ := strconv.Atoi(r.URL.Query().Get("ms"))
		_, span := tracer.Start(r.Context(), "do-work")
		span.SetAttributes(attribute.Int("work.ms", ms))
		if fail := r.URL.Query().Get("fail"); fail != "" {
			if p, err := strconv.ParseFloat(fail, 64); err == nil && rand.Float64() < p {
				time.Sleep(time.Duration(ms) * time.Millisecond)
				span.SetAttributes(attribute.Bool("work.failed", true))
				span.End()
				http.Error(w, "injected failure", http.StatusInternalServerError)
				return
			}
		}
		time.Sleep(time.Duration(ms) * time.Millisecond)
		span.End()
		fmt.Fprintf(w, "done by %s", name)
	})

	// /call is service A calling service B. The otelhttp transport INJECTS the
	// W3C traceparent header, so B's span becomes a child of A's span -> one trace.
	app.HandleFunc("/call", func(w http.ResponseWriter, r *http.Request) {
		if upstream == "" {
			http.Error(w, "no UPSTREAM configured", http.StatusBadRequest)
			return
		}
		ms := r.URL.Query().Get("ms")
		if ms == "" {
			ms = "50"
		}
		client := http.Client{
			Transport: otelhttp.NewTransport(http.DefaultTransport), // propagation + client span
			Timeout:   5 * time.Second,
		}
		req, _ := http.NewRequestWithContext(r.Context(), http.MethodGet, upstream+"/work?ms="+ms, nil)
		resp, err := client.Do(req)
		if err != nil {
			http.Error(w, "upstream error: "+err.Error(), http.StatusBadGateway)
			return
		}
		defer resp.Body.Close()
		body, _ := io.ReadAll(resp.Body)
		w.WriteHeader(resp.StatusCode)
		fmt.Fprintf(w, "%s -> [%d] %s", name, resp.StatusCode, body)
	})

	// Wrap the app in otelhttp (server spans, context extraction) then RED metrics.
	instrumented := redMiddleware(otelhttp.NewHandler(app, "http.server",
		otelhttp.WithSpanNameFormatter(func(_ string, r *http.Request) string {
			return r.Method + " " + r.URL.Path
		}),
	))

	root := http.NewServeMux()
	root.Handle("/metrics", promhttp.Handler()) // scraped by Prometheus; not traced
	root.Handle("/", instrumented)

	srv := &http.Server{Addr: ":" + port, Handler: root}
	go func() {
		log.Printf("%s listening on :%s (upstream=%q, otlp=%s)", name, port, upstream, otlpEndpoint)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal(err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt)
	<-stop
	_ = srv.Shutdown(ctx)
}

// initTracing wires an OTLP/HTTP exporter -> Jaeger and sets the global W3C
// TraceContext propagator (the thing that makes A->B a single trace).
func initTracing(ctx context.Context, name, endpoint string) func(context.Context) error {
	exp, err := otlptracehttp.New(ctx,
		otlptracehttp.WithEndpoint(endpoint), // host:port, no scheme
		otlptracehttp.WithInsecure(),         // lab only — plaintext to local Jaeger
	)
	if err != nil {
		log.Fatalf("otlp exporter: %v", err)
	}
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exp),
		sdktrace.WithResource(resource.NewSchemaless(attribute.String("service.name", name))),
		// Lab: sample everything so every request shows up. In prod you would
		// head-sample low + tail-sample errors/slow (see content/day11.md).
		sdktrace.WithSampler(sdktrace.AlwaysSample()),
	)
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{}, propagation.Baggage{}))
	return tp.Shutdown
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
