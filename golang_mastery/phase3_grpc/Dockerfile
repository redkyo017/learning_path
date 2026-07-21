FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /bin/grpc-server ./cmd/server

FROM gcr.io/distroless/static-debian12
COPY --from=builder /bin/grpc-server /grpc-server
EXPOSE 50051 9090
ENTRYPOINT ["/grpc-server"]
