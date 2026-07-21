# Runbook: Go Module and Dependency Troubleshooting

**When to use this runbook:**
- Build errors: `cannot find package`, `missing go.sum entry`, `ambiguous import`
- Version conflicts: two packages require incompatible versions of the same dependency
- `go.sum` mismatch or checksum failures
- Workspace (`go.work`) sync issues between modules
- Build failures with private modules (auth errors, proxy failures)
- `replace` directive not working as expected

---

## Background

Go modules manage dependencies via `go.mod` (which versions you want) and `go.sum` (cryptographic checksums of those versions). The module proxy (`proxy.golang.org` by default) is the intermediary that fetches and caches modules. The sum database (`sum.golang.org`) verifies checksums.

Understanding the request flow helps debug failures:

```
go get github.com/foo/bar@v1.2.3
  │
  ├─ check local cache ($GOPATH/pkg/mod/cache)
  │
  ├─ if not cached: fetch from GOPROXY (proxy.golang.org)
  │
  ├─ verify checksum against GONOSUMDB / GONOSUMCHECK rules
  │   └─ if not excluded: verify against sum.golang.org
  │
  └─ update go.mod and go.sum
```

---

## Step 1: `go mod tidy` — the first tool to reach for

`go mod tidy` is the most common fix. Run it whenever:
- You added or removed an import in your code
- You upgraded a dependency
- You switched Go versions
- The build fails with `missing go.sum entry` or `cannot find module providing package`

```bash
# What go mod tidy does:
# 1. Adds missing module requirements to go.mod
# 2. Removes requirements that are no longer used
# 3. Updates go.sum with checksums for all direct and indirect dependencies
go mod tidy

# Expected output (usually silent — errors indicate real problems):
# go: downloading github.com/foo/bar v1.2.3

# Verify the module graph after tidy
go mod verify
# Expected: all modules verified

# Show all direct and indirect dependencies
go list -m all

# Show why a module is required
go mod why github.com/foo/bar
```

**If `go mod tidy` changes `go.mod` or `go.sum`:** commit both files. Keeping them in sync with the code prevents "works on my machine" build failures.

---

## Step 2: Go workspace sync (`go work sync`)

Go workspaces (`go.work`) let you work on multiple modules simultaneously by replacing module requirements with local paths. Use them when:
- You are developing a library and its consumer in parallel
- You have a monorepo with multiple modules

```bash
# Initialize a workspace
go work init ./module-a ./module-b

# go.work file contents:
# go 1.22
# use (
#   ./module-a
#   ./module-b
# )

# Sync — updates go.work.sum and resolves version conflicts between modules
go work sync

# Add a module to the workspace
go work use ./module-c

# Check if any workspace module is out of sync
go work sync && go build ./...
```

### Common workspace sync failures

```
go: workspace module github.com/myorg/module-a has conflicting requirements:
        github.com/foo/bar v1.2.3
        github.com/foo/bar v1.3.0
```

This means two modules in your workspace require incompatible versions of the same dependency. Fix: update the lower-version module:

```bash
cd module-a
go get github.com/foo/bar@v1.3.0
go mod tidy
cd ..
go work sync
```

### Do not commit `go.work` to production repositories

`go.work` is for local development. Add it to `.gitignore` (or only commit it if the repo is specifically a workspace repo). CI should use the individual modules' `go.mod` files.

---

## Step 3: Version conflicts

### Understanding Go's Minimum Version Selection (MVS)

Go uses MVS: when two dependencies require different versions of a third package, Go picks the **minimum version that satisfies all requirements**. This is almost always the higher of the two required versions.

```bash
# See the full dependency graph
go mod graph

# Find all versions of a specific module in the graph
go mod graph | grep github.com/foo/bar

# Example output:
# mymodule github.com/foo/bar@v1.2.3
# github.com/other/lib@v1.0.0 github.com/foo/bar@v1.3.0
# → Go will use v1.3.0 (highest minimum)
```

### Getting a specific version

```bash
# Upgrade to a specific version
go get github.com/foo/bar@v1.3.0

# Upgrade to latest
go get github.com/foo/bar@latest

# Downgrade to a specific version
go get github.com/foo/bar@v1.1.0

# After any go get, run tidy
go mod tidy
```

### `replace` directive

Use `replace` to:
- Point a module at a local path (during development)
- Force a different version than what MVS selects
- Replace a broken upstream with a fork

```
// go.mod

// Replace with local fork (development)
replace github.com/foo/bar => ../local-fork

// Replace with specific version (override MVS)
replace github.com/foo/bar v1.2.3 => github.com/foo/bar v1.2.4

// Replace with a different module entirely
replace github.com/foo/bar => github.com/myfork/bar v1.0.0
```

```bash
# Add a replace directive from the command line
go mod edit -replace github.com/foo/bar=../local-fork

# Remove a replace directive
go mod edit -dropreplace github.com/foo/bar
```

**Warning:** `replace` directives in a library module do not propagate to its consumers. They only affect the top-level module (the binary being built). If you publish a library with a `replace` directive, it is ignored by anyone who imports your library.

---

## Step 4: `go.sum` mismatch

The `go.sum` file records the expected hash of each downloaded module. If the hash does not match, the build fails.

### Common causes

| Error | Cause | Fix |
|---|---|---|
| `missing go.sum entry for module providing package` | Package was added to code but `go.sum` was not updated | `go mod tidy` |
| `SECURITY ERROR: verifying module` | Module hash from proxy does not match sum database | May indicate tampering; investigate before bypassing |
| `checksum mismatch` | `go.sum` records a different hash than what the proxy returns | Module may have been replaced/republished upstream; see below |

### Regenerate `go.sum` from scratch

If `go.sum` is corrupted or you need to start fresh:

```bash
# Remove go.sum and regenerate
rm go.sum
go mod download  # downloads all dependencies and regenerates go.sum
go mod verify    # verify all downloaded modules
```

### Add a missing checksum

```bash
# Download and add checksum for a specific module
go mod download github.com/foo/bar@v1.2.3

# Or just run tidy
go mod tidy
```

### Skip sum verification for specific modules

```bash
# Skip sum database for a specific module (use for private/internal modules)
GONOSUMCHECK=github.com/mycompany/* go mod tidy

# Or set permanently in go env
go env -w GONOSUMCHECK=github.com/mycompany/*

# Skip sum database for ALL modules (never use in production CI)
GONOSUMDB=* go mod tidy
```

**Do not use `GONOSUMDB=*` in CI** unless you are in a fully air-gapped environment. It disables all tamper detection.

---

## Step 5: Private modules

### The problem

The Go toolchain, by default:
1. Tries to fetch all modules from `proxy.golang.org`
2. Verifies checksums against `sum.golang.org`

Private modules (internal GitHub orgs, private GitLab) are not on the public proxy. Fetching them fails with:

```
go: github.com/mycompany/internal: reading https://proxy.golang.org/...: 410 Gone
```

### The fix: `GOPRIVATE`

`GOPRIVATE` is a comma-separated list of module path prefixes that should bypass the proxy and sum database and be fetched directly:

```bash
# Set for one command
GOPRIVATE=github.com/mycompany go get github.com/mycompany/internal@latest

# Set permanently (stored in go env)
go env -w GOPRIVATE=github.com/mycompany/*,gitlab.mycompany.com/*
```

`GOPRIVATE` is shorthand for setting both `GONOSUMDB` and `GONOPROXY` to the same value.

### If authentication fails when fetching private modules

Go uses `git` under the hood to fetch from GitHub/GitLab. Configure git credentials:

```bash
# For HTTPS with a personal access token
git config --global url."https://TOKEN@github.com/".insteadOf "https://github.com/"

# For SSH
git config --global url."git@github.com:".insteadOf "https://github.com/"

# Verify git can access the private repo
git ls-remote https://github.com/mycompany/internal.git
```

### Using a private module proxy

If your organization runs an internal module proxy (Athens, Artifactory, Nexus):

```bash
# Set proxy with fallback to public proxy
go env -w GOPROXY="https://internal-proxy.mycompany.com,https://proxy.golang.org,direct"

# Set proxy for private modules only
go env -w GOPROXY="https://internal-proxy.mycompany.com|direct"
go env -w GOPRIVATE=github.com/mycompany/*
```

---

## Diagnostic commands: full reference

```bash
# Show current go env settings
go env GOPROXY GONOSUMDB GOPRIVATE GONOSUMCHECK

# Show all required modules
go list -m all

# Show why a module is needed (traces the require chain)
go mod why github.com/foo/bar

# Show all versions of a module available
go list -m -versions github.com/foo/bar

# Download all dependencies without building
go mod download

# Verify all module checksums against go.sum
go mod verify

# Visualize the dependency graph (pipe to dot for a graph image)
go mod graph | grep "^mymodule " | head -20

# Remove all dependencies from module cache (nuclear option)
go clean -modcache
```

### If all else fails: clean and rebuild

```bash
# Remove the build cache
go clean -cache

# Remove the module download cache
go clean -modcache

# Delete go.sum and regenerate
rm go.sum
go mod tidy
go mod verify
go build ./...
```

---

## Quick decision tree

```
Build fails with import/module error
  │
  ├─ "cannot find package / missing go.sum"
  │     └─ go mod tidy
  │
  ├─ "410 Gone" from proxy.golang.org
  │     └─ private module → set GOPRIVATE
  │
  ├─ "SECURITY ERROR: verifying module"
  │     └─ investigate before bypassing; check if module was republished
  │
  ├─ version conflict
  │     └─ go mod graph | grep problematic-module
  │     └─ go get module@higher-version + go mod tidy
  │
  ├─ replace directive not working
  │     └─ check if you are in the top-level module (replace is ignored in libraries)
  │
  └─ workspace sync failure
        └─ go work sync
        └─ update the module with the lower version requirement
```
