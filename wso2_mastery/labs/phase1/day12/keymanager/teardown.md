# Day 12 Teardown

## Stop Docker Compose

```bash
cd labs/phase1/day12/keymanager
docker compose down
```

This stops and removes the container.  The image is kept so the next
`docker compose up --build` is faster (Docker cache).

## Remove the image (optional)

```bash
docker compose down --rmi local
```

## Remove all Day 12 Docker artefacts

```bash
docker compose down --rmi local --volumes --remove-orphans
```

## Clean up temporary files

```bash
rm -f /tmp/km_app.json /tmp/km_token.json
```

## Clean up Go module files (optional)

```bash
cd labs/phase1/day12/keymanager
rm -f go.mod go.sum
```

Re-run `go mod init keymanager && go get github.com/golang-jwt/jwt/v5` to restore.

## State

All client registrations and revoked tokens live in process memory inside the
container.  `docker compose down` discards them entirely.  No volumes were
mounted, so nothing persists to disk.
