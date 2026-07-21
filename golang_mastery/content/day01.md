# Day 1 — Toolchain & Project Layout

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Explain what a `go.work` file does and why it exists alongside `go.mod`
- Read a `go.mod` file with a `toolchain` directive and explain what it controls
- Write a correct `//go:build` constraint and know why the old `// +build` form is deprecated
- State the exact difference between `go install` and `go get` in Go 1.17+
- Describe the standard `cmd/`, `internal/`, and module layout for a multi-phase project

---

## The module graph is a tree — go.work is the root

Before Go 1.18, working on two related modules simultaneously was painful. If
`module-a` depended on `module-b` and you were developing both at the same time,
you had to add a `replace` directive in `module-a`'s `go.mod` pointing at a local
path. That directive was a personal development artifact that you must not commit,
creating a constant source of "who removed the replace directive?" conflicts.

Workspace mode (`go.work`) solves this cleanly. Think of a `go.work` file as the
single root node of your local multi-module development tree. The `go.work` file
is a workspace-level concern — it lives at the root of your development tree and
is typically gitignored. Each module keeps its own clean `go.mod` with no local
replace directives. When the Go toolchain runs in a directory with a `go.work`
file (or a parent directory), it uses the workspace's module graph, where any
`use` directive overrides the published version of that module.

The analogy: think of `go.work` the way you'd think of a monorepo root manifest.
It doesn't add dependencies — it tells the toolchain which local directories
contain the canonical source for a module that might also exist in the module
cache. Everything inside a `use` directive takes precedence. Remove the
`go.work` file and the toolchain falls back to the published module versions as
if you had never touched it.

For this learning path, the single `golang_mastery/go.work` wires together four
independent modules (`phase1_cli`, `phase2_rest`, `phase3_grpc`, `phase4_gateway`).
Each phase module is independently buildable and testable. Later phases can import
code from earlier phases without publishing anything to a registry.

---

## Workspace mode: go.work

A `go.work` file has three possible directives:

```
go 1.22

use (
    ./phase1_cli
    ./phase2_rest
)

replace example.com/broken => ./local/fix
```

| Directive | What it does |
|---|---|
| `go` | Minimum Go version for the workspace (not for any individual module) |
| `use` | Adds a local module directory to the workspace module graph |
| `replace` | Same semantics as `go.mod` replace — use sparingly |

Key commands:

```bash
go work init ./phase1_cli  # create go.work with one module
go work use ./phase2_rest  # add a second module
go work sync               # sync go.work.sum with all modules' requirements
GOWORK=off go build ./...  # temporarily disable workspace mode
```

The `go.work.sum` file is automatically maintained — commit it alongside
`go.work` when you do commit the workspace file (though many teams gitignore
both and regenerate locally).

---

## The toolchain directive (Go 1.21+)

Before 1.21, `go 1.22` in a `go.mod` declared the minimum Go version you
required of the *user's toolchain*. It did not specify which toolchain to
*download*. Since 1.21, there is a new `toolchain` directive:

```
module github.com/yourname/golang-mastery/phase1-cli

go 1.22

toolchain go1.22.4
```

The `toolchain` directive names the exact toolchain version the module was
*developed with*. If a user's installed `go` binary is older, Go 1.21+ can
automatically download and use the declared toolchain version (using GOTOOLCHAIN
env var behavior). The `go` directive remains the *minimum*; the `toolchain`
directive is the *preferred* — they are different concepts.

Three GOTOOLCHAIN values to know:

| Value | Behavior |
|---|---|
| `local` | Never download; use whatever `go` is in PATH |
| `auto` (default since 1.21) | Download if the module requires a newer toolchain |
| `go1.22.4` | Pin to exactly this version |

In practice: set `toolchain` in `go.mod` to the version you built and tested
with. Your CI should have `GOTOOLCHAIN=local` and install the exact version you
specified so it never silently upgrades.

---

## Build constraints: //go:build vs // +build

Before Go 1.17, build constraints used a magic comment form:

```go
// +build linux,amd64 darwin
// +build !cgo
```

This syntax was error-prone: the constraint had to be followed by a blank line,
the boolean logic (`AND` = comma, `OR` = space) was counterintuitive, and there
was no way to lint it.

Go 1.17 introduced the `//go:build` form:

```go
//go:build (linux && amd64) || darwin
//go:build !cgo
```

The new form uses Go's normal boolean operators (`&&`, `||`, `!`) with
parentheses. It is linted by `go vet`. Go 1.17 also made `gofmt` automatically
add the `//go:build` form alongside the old form if only the old form was
present.

As of Go 1.17+: **always write `//go:build`**. The old `// +build` form still
compiles, but `go vet` will warn about files that have only the old form. If
both are present, they must agree — `go vet` checks this too.

Special tag values to know:

| Tag | Meaning |
|---|---|
| `ignore` | Never build this file (useful for draft files in a package) |
| `integration` | Convention for integration tests (must be set via `-tags integration`) |
| `GOOS` (e.g. `linux`) | Platform-specific build |
| `GOARCH` (e.g. `amd64`) | Architecture-specific build |

---

## go install vs go get

This was clarified in Go 1.16 and completed in 1.17. Before this, both commands
did overlapping things. Now they are strictly separated:

| Command | Purpose | Changes go.mod? |
|---|---|---|
| `go get example.com/tool@v1.2.3` | Add or update a dependency in the current module | Yes |
| `go install example.com/tool@latest` | Install a binary into `$GOPATH/bin` | No |
| `go get -u ./...` | Upgrade all dependencies in the current module | Yes |
| `go install ./cmd/mytool` | Build and install a binary from the current module | No |

The critical rule: **never use `go get` to install tools globally**. Use
`go install` with a full module path and explicit version. The reason: `go get`
without a module context modifies a `go.mod` file, and running it globally
(outside a module) has been removed as of Go 1.17.

For tool management in a team project, the standard pattern is a `tools.go` file:

```go
//go:build tools

package tools

import (
    _ "github.com/golangci/golangci-lint/cmd/golangci-lint"
    _ "golang.org/x/tools/cmd/goimports"
)
```

This is a blank-import-only file with a `tools` build tag (so it never compiles
into your binary) that anchors tool versions in `go.mod`. You then use
`go install` to install them.

---

## Standard project layout

There is no official Go project layout specification, but there is a widely
adopted convention:

```
module-root/
├── go.mod
├── cmd/
│   └── myservice/
│       └── main.go        ← binary entrypoint (one per binary)
├── internal/
│   ├── handler/           ← exported to this module only
│   ├── repository/
│   └── model/
├── pkg/                   ← shared code intended for external use
│   └── clientlib/
└── Dockerfile
```

The key rules:

**`cmd/`** — one directory per binary. Each sub-directory has a `main.go`.
Nothing inside `cmd/` should contain significant logic — it wires together
packages and calls `os.Exit`. Business logic lives in `internal/` or `pkg/`.

**`internal/`** — the Go compiler enforces visibility: only code rooted at the
same module (or parent directory of `internal/`) can import packages from
`internal/`. This is not just a convention — it is a compiler rule. Use it to
prevent external consumers from depending on implementation details.

**`pkg/`** — optional. Only create it if you have packages you intend to export
as a stable API for other modules. If in doubt, use `internal/` and move to
`pkg/` when you have confirmed stability.

---

## Module cache: structure and location

```bash
go env GOMODCACHE   # typically ~/go/pkg/mod
go env GOPATH       # parent of pkg/mod
```

The module cache directory layout mirrors the module path:

```
$GOMODCACHE/
├── github.com/
│   └── gin-gonic/
│       └── gin@v1.9.1/        ← exact version, immutable
│           ├── go.mod
│           ├── gin.go
│           └── ...
└── golang.org/
    └── x/
        └── sync@v0.7.0/
```

Two important properties:
1. Module cache directories are **read-only** (`chmod 555`). The Go toolchain
   sets this deliberately to prevent accidental modification. If you need to
   edit a dependency, use `go work use` or `replace`, not direct edits.
2. The module cache is **shared across all modules on your machine**. Clearing
   it (`go clean -modcache`) removes all cached modules and forces re-download
   on next build.

---

## Returning engineer: what changed since 1.16–1.18

**The `go.work` / `replace` story:** You may have used `replace` directives to
link local modules. Do not bring that habit to this project. The `go.work` file
is the right tool for local multi-module development. Never commit `replace`
directives that point at local paths.

**`go get` for tools is gone:** If you have a muscle memory habit of
`go get github.com/some/tool` to install CLI tools, that no longer works outside
a module (and modifies `go.mod` inside one). Use `go install
github.com/some/tool@latest` for anything you want in your `$PATH`.

**The `toolchain` directive is new since 1.21:** If you see a `go.mod` with both
`go 1.22` and `toolchain go1.22.4`, do not be confused — they are different
things. You did not have this in 1.16–1.18.

**`//go:build` vs `// +build`:** You almost certainly wrote `// +build` in your
pre-management era code. Any file you write now should use only `//go:build`.
Running `gofmt` on old files will add the new form automatically, but the old
form stays too — you have to delete it manually (or run `go fix ./...` with the
`buildtag` fix).

**`GOPATH` mode is dead:** If you ever worked in `GOPATH` mode before modules,
forget it entirely. Every project is a module now. `GO111MODULE=off` is a path to
pain.

---

## Key concepts to memorize

- `go.work` is gitignored; `go.mod` is committed — they solve different problems
- `use ./phase1_cli` in `go.work` overrides the published version of that module
- `go` in `go.mod` = minimum required Go version; `toolchain` = preferred build toolchain
- `//go:build` uses normal boolean operators (`&&`, `||`, `!`); `// +build` uses comma/space
- `go install` installs binaries; `go get` manages `go.mod` dependencies
- `internal/` visibility is enforced by the compiler, not just convention
- Module cache is read-only; use `go work` or `replace` directives, never edit directly
- `GOMODCACHE` defaults to `$GOPATH/pkg/mod`

---

## Common mistakes

**1. Committing `replace` directives pointing at local paths.**
Why it happens: muscle memory from before `go.work` existed. A colleague checks
out your branch and gets build failures because the local path doesn't exist on
their machine. Fix: use `go.work` for local development, never commit local-path
`replace` directives.

**2. Running `go get` to install a CLI tool.**
Why it happens: this worked before Go 1.17. Now `go get` inside a module
modifies `go.mod`; outside a module it errors. Use `go install tool@version`
for binaries.

**3. Writing `// +build` constraints on new files.**
Why it happens: the old form still compiles, so there's no immediate error.
But `go vet` will warn, and the logic notation (`// +build linux,amd64` = `AND`)
is a trap. New files: `//go:build` only.

**4. Putting logic in `cmd/` packages.**
Why it happens: it feels convenient to add a helper function right next to
`main`. Then another binary in a different `cmd/` directory needs the same
function and can't import it (only `main` packages can't be imported). Fix:
keep `cmd/` packages as thin wiring; all logic lives in `internal/`.

**5. Not understanding that `internal/` is compiler-enforced.**
Why it happens: engineers assume it's a convention like `pkg/`. It is not —
the compiler will refuse to compile a module that tries to import another
module's `internal/` package. This is intentional. If you want to share a
package with the outside world, it must live outside `internal/`.

---

## Check your understanding

1. You have a `go.work` file with `use ./phase1_cli`. You run
   `go build ./phase2_rest/...` from the workspace root. Which version of
   `phase1_cli` does `phase2_rest` see — the one in the module cache or the
   local directory? Why?
2. A `go.mod` has `go 1.22` and `toolchain go1.22.4`. A developer has Go 1.21
   installed and `GOTOOLCHAIN=auto`. What happens when they run `go build`?
3. You find a file in a codebase with both `//go:build linux` and
   `// +build linux`. Is this a problem? What does `go vet` say, and what does
   `gofmt` do?

(answers are in the code — run the lab to verify)
