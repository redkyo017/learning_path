# Stage 1 — build a fully static arm64 binary.
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS build

ARG VERSION=dev
ARG GIT_COMMIT=unknown

WORKDIR /src
COPY go.mod ./
COPY main.go ./

# CGO off + scratch base = no libc, no shell, no package manager, ~15MB image.
RUN CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build \
      -trimpath \
      -ldflags="-s -w -X main.version=${VERSION} -X main.gitCommit=${GIT_COMMIT}" \
      -o /out/app .

# Stage 2 — the artifact. Pinned to linux/arm64 explicitly: with no
# --platform here this stage would inherit the BUILD host's platform (the
# default target when none is passed to `docker build`), not the arm64
# binary GOARCH=arm64 above actually produced. On an x86 host that mismatch
# ships an image labelled linux/amd64 containing an arm64 binary, which
# fails at container start with "exec format error" — exactly the failure
# Day 4's local `kind` run would hit.
FROM --platform=linux/arm64 scratch
COPY --from=build /out/app /app
EXPOSE 8080
ENTRYPOINT ["/app"]
