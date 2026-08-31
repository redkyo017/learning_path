FROM golang:1.22-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o keymanager .

FROM alpine:3.19
WORKDIR /app
COPY --from=build /app/keymanager .
EXPOSE 9444
CMD ["./keymanager"]
