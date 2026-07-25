# Static build of the orders service (used for both v1 and v2).
FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod .
COPY main.go .
RUN CGO_ENABLED=0 go build -o /orders .

FROM gcr.io/distroless/static-debian12
COPY --from=build /orders /orders
EXPOSE 8080
ENTRYPOINT ["/orders"]
