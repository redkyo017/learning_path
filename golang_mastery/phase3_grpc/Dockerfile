# Stage 1: fetch grpc-health-probe for the target architecture (used by the ECS health check)
FROM alpine:3.24 AS health-probe
ARG TARGETARCH
RUN apk add --no-cache curl && \
    curl -fsSL -o /bin/grpc-health-probe \
    "https://github.com/grpc-ecosystem/grpc-health-probe/releases/download/v0.4.60/grpc_health_probe-linux-${TARGETARCH}" && \
    chmod +x /bin/grpc-health-probe

# Stage 2: build (gen/ must exist: run `buf generate` first)
FROM --platform=$BUILDPLATFORM golang:1.27-alpine AS builder
ARG TARGETOS TARGETARCH
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w" -o /bin/grpc-server ./cmd/server

# Stage 3: minimal runtime, non-root (UID 65532)
FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=health-probe /bin/grpc-health-probe /bin/grpc-health-probe
COPY --from=builder /bin/grpc-server /grpc-server
EXPOSE 50051 9090
ENTRYPOINT ["/grpc-server"]
