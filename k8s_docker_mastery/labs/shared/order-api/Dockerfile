# syntax=docker/dockerfile:1
# ==============================================================================
# Production multi-stage Dockerfile for order-api
# ==============================================================================

# Stage 1: build with the Go toolchain. Runs natively on the build host
# ($BUILDPLATFORM) and cross-compiles for the target, so an Apple Silicon Mac can
# produce linux/amd64 images without emulation.
FROM --platform=$BUILDPLATFORM golang:1.27-alpine AS builder
ARG TARGETOS TARGETARCH

WORKDIR /app

# Dependency manifest first, so this layer is cached until it changes.
# This module has no dependencies, hence no go.sum. In a module with
# dependencies you would write: COPY go.mod go.sum* ./  (the glob keeps the
# COPY from failing when go.sum is absent) followed by RUN go mod download.
COPY go.mod ./

# Source, then a static build. Cache mounts keep the module and build caches
# between builds without baking them into any layer.
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w" -o /app/server .

# Stage 2: minimal runtime image. Distroless static has CA certs and tzdata
# only: no shell, no package manager.
FROM gcr.io/distroless/static-debian13:nonroot

WORKDIR /app
COPY --from=builder /app/server /app/server

EXPOSE 8080

# Numeric UID:GID so Kubernetes runAsNonRoot can verify it without runAsUser.
USER 65532:65532

# No curl in distroless, so the binary probes itself: GET /health on $PORT, exit 0/1.
HEALTHCHECK --interval=10s --timeout=3s --start-period=3s --retries=3 CMD ["/app/server", "-healthcheck"]

ENTRYPOINT ["/app/server"]
