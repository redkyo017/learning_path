# Minimal static build of the echo service.
FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod .
COPY main.go .
RUN CGO_ENABLED=0 go build -o /echo .

FROM gcr.io/distroless/static-debian12
COPY --from=build /echo /echo
EXPOSE 8080
ENTRYPOINT ["/echo"]
