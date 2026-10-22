# Stage 1: build (runs natively on the build host; cross-compiles for the target)
FROM --platform=$BUILDPLATFORM golang:1.27-alpine AS builder
ARG TARGETOS TARGETARCH
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w" -o /bin/api ./cmd/api

# Stage 2: minimal runtime, non-root (UID 65532)
FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=builder /bin/api /api
EXPOSE 8080
ENTRYPOINT ["/api"]
