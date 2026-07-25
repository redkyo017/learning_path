// Day 11 observability lab module.
//
// These require lines are a known-good, coherent OTel + Prometheus set. They need
// the network ONCE to resolve: run `go mod tidy` (it will add go.sum and any
// transitive deps). If a version is unavailable in your environment, `go mod tidy`
// will pick compatible ones — the code uses stable OTel v1 / contrib v0.5x APIs.
module lab/obs

go 1.22

require (
	github.com/prometheus/client_golang v1.19.1
	go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp v0.53.0
	go.opentelemetry.io/otel v1.28.0
	go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp v1.28.0
	go.opentelemetry.io/otel/sdk v1.28.0
)
