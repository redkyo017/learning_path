# Day 12 — Protobuf + buf

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

- Explain proto3 field-number immutability and why it is the central constraint in schema evolution
- Write a complete `.proto` file with messages, enums, a service, and well-known types
- Configure `buf.yaml` and `buf.gen.yaml` to replace a raw `protoc` workflow
- Classify any schema change as backwards-compatible or breaking before committing it
- Run `buf breaking` to enforce compatibility in CI

---

## Core mental model

**Field numbers are forever — change a name freely, never change a number in a deployed schema.**

Protobuf serialises each field as a `(field_number, wire_type, value)` triplet. The field *name* is not in the wire format at all. That has two consequences:

1. You can rename a field without breaking any existing binary. Old clients continue to decode correctly because they match on the number, not the name.
2. If you reuse a number — even after deleting the original field — an old client holding stale data will decode the new field's bytes into the old field's type, producing silent corruption.

The safe rule: reserve the number with `reserved 4;` or `reserved "old_name";` before you delete anything.

---

## Proto3 syntax essentials

### Messages and field rules

```proto
syntax = "proto3";

package payments.v1;

option go_package = "github.com/example/gen/go/payments/v1;paymentsv1";

message Payment {
  string  id          = 1;
  int64   amount_cents = 2;
  string  currency    = 3;
  Status  status      = 4;
  google.protobuf.Timestamp created_at = 5;
}
```

Key rules:
- Field numbers 1–15 occupy one byte on the wire (use them for frequently-set fields).
- Field numbers 16–2047 occupy two bytes.
- Field numbers 19000–19999 are reserved by the Protobuf runtime — never use them.
- Every field in proto3 is implicitly optional; the default value for all scalar types is the zero value.
- Explicit `optional` keyword (proto3 optional) adds a `HasX()` method in generated Go so you can distinguish "absent" from "zero value set".

### Enums

```proto
enum Status {
  STATUS_UNSPECIFIED = 0;   // always required — the zero value
  STATUS_PENDING     = 1;
  STATUS_SETTLED     = 2;
  STATUS_FAILED      = 3;
}
```

Rules:
- The first value must be 0. Name it `FOO_UNSPECIFIED`, not `FOO_NONE` (buf lint enforces this).
- An unknown enum value decodes to 0 on proto3 — your code must handle `UNSPECIFIED` gracefully.

### Services and RPCs

```proto
service PaymentService {
  rpc CreatePayment(CreatePaymentRequest) returns (CreatePaymentResponse);
  rpc StreamPayments(StreamPaymentsRequest) returns (stream PaymentEvent);
}
```

### Well-known types (WKTs)

Import from `google/protobuf/`:

| WKT | Go type generated | Use case |
|-----|-------------------|----------|
| `google.protobuf.Timestamp` | `*timestamppb.Timestamp` | wall-clock time, always UTC |
| `google.protobuf.Duration` | `*durationpb.Duration` | elapsed time, retry windows |
| `google.protobuf.Empty` | `*emptypb.Empty` | RPCs with no meaningful request/response body |
| `google.protobuf.StringValue` | `*wrapperspb.StringValue` | nullable string (distinguishes absent from "") |
| `google.protobuf.FieldMask` | `*fieldmaskpb.FieldMask` | partial updates / PATCH semantics |

Convert from Go types cleanly:

```go
import "google.golang.org/protobuf/types/known/timestamppb"

req.CreatedAt = timestamppb.New(time.Now())
t := req.CreatedAt.AsTime()  // back to time.Time
```

---

## buf: the modern proto toolchain

### Why buf replaces raw protoc

With raw `protoc` you had to:
1. Install `protoc` binary manually (version drift between machines).
2. Manage every `--proto_path` flag by hand.
3. Run separate plugin binaries (`protoc-gen-go`, `protoc-gen-go-grpc`) and keep versions pinned somewhere ad-hoc.
4. Lint by convention, not enforcement.
5. No built-in breaking-change detection.

`buf` solves all of this:
- Single binary, declarative config, no `--proto_path` gymnastics.
- Plugins are version-pinned in `buf.gen.yaml` and fetched from the Buf Schema Registry (BSR) or locally.
- `buf lint` enforces an opinionated style guide (field naming, enum prefixes, package naming).
- `buf breaking` detects wire-incompatible changes automatically.
- `buf dep update` manages WKT and third-party `.proto` imports.

### buf.yaml — module definition

```yaml
version: v2
modules:
  - path: proto
lint:
  use:
    - DEFAULT
breaking:
  use:
    - FILE          # catches all wire-breaking changes
deps:
  - buf.build/googleapis/googleapis   # WKTs and google/api/annotations
```

Place this at the repo root. `proto/` is the directory that contains your `.proto` files.

### buf.gen.yaml — code generation

```yaml
version: v2
inputs:
  - directory: proto
plugins:
  - remote: buf.build/protocolbuffers/go        # generates .pb.go
    out: gen/go
    opt:
      - paths=source_relative
  - remote: buf.build/grpc/go                   # generates _grpc.pb.go
    out: gen/go
    opt:
      - paths=source_relative
      - require_unimplemented_servers=false
```

Run with:

```bash
buf generate          # generates all code
buf lint              # fails CI if style violations exist
buf breaking --against .git#branch=main   # compare current tree vs main
```

---

## Backwards-compatible changes vs breaking changes

| Change | Compatible? | Why |
|--------|-------------|-----|
| Add a new field with a new number | Yes | Old clients ignore unknown fields |
| Rename a field | Yes | Wire format uses number, not name |
| Add a new enum value | Yes (with care) | Old clients decode unknown value as 0 |
| Add a new RPC to a service | Yes | Old clients simply don't call it |
| Delete a field (number reserved) | Yes | Old clients never receive it |
| Delete a field (number NOT reserved) | **Breaking** | Number may be reused — silent corruption |
| Change a field's type (e.g. `int32` → `int64`) | **Breaking** | Different wire type — decode fails |
| Change a field number | **Breaking** | Old clients read wrong field |
| Remove a required enum value (value 0) | **Breaking** | All existing zero-value fields become invalid |
| Change a singular field to `repeated` | **Breaking** | Wire encoding differs |
| Rename a package | **Breaking** | Fully-qualified type names embedded in `Any` break |
| Rename an RPC method | **Breaking** | gRPC method path is `/package.Service/Method` |

---

## Returning engineer: what changed since 1.16–1.18

In the 1.16–1.18 era:

- **`protoc` was the only real option.** Makefiles or shell scripts called `protoc` with hand-managed `--proto_path` flags. This was fragile across team machines.
- **`github.com/golang/protobuf` was the Go Protobuf library.** It is now deprecated. The canonical library is `google.golang.org/protobuf` (the "v2" API). The old `ptypes` package (e.g., `ptypes.MarshalAny`) is gone — use `anypb.MarshalFrom` instead.
- **`protoc-gen-go` and `protoc-gen-go-grpc` were separate, loosely versioned.** `buf` pins both via `buf.gen.yaml` and handles fetching.
- **There was no standard breaking-change enforcement.** Teams relied on code review or custom scripts.
- **`buf` existed but was immature.** As of 2024–2025 it is the industry standard. The Buf Schema Registry (BSR) is the equivalent of npm/pkg.go.dev for `.proto` files.
- **`google.golang.org/grpc/cmd/protoc-gen-go-grpc` v1.3+ changed the generated interface.** If you copy-paste old generated code you'll find the server interface changed — `require_unimplemented_servers` is now on by default (your server must embed `UnimplementedXxxServer`).

---

## Key concepts to memorize

- Field numbers are the wire identity of a field — names are only for source code
- proto3 zero value for all scalars; use `proto3 optional` when you need nil distinction
- WKT import path pattern: `google/protobuf/timestamp.proto`; Go package `timestamppb`
- `buf.yaml` = module definition + lint + breaking rules
- `buf.gen.yaml` = code generation config
- `reserved` keyword must be used for both numbers and names when deleting a field
- `buf breaking --against .git#branch=main` is the standard CI gate

---

## Common mistakes

**1. Deleting a field without reserving the number**

*Why it matters:* If the number is reused later (by any team member, any future version), clients holding old data will silently misparse the new field. The bug often does not surface until production.

*How to avoid:* Add `reserved 4; reserved "old_field_name";` immediately when deleting. Treat `reserved` as a permanent tombstone.

**2. Using `int64` for monetary amounts and then sending via JSON**

*Why it matters:* Protobuf JSON encoding serialises `int64` as a string to avoid JavaScript precision loss. Consumers that expect a JSON number will fail. This is the correct behaviour, but it surprises teams switching from REST.

*How to avoid:* Document your JSON transcoding contract. Use `int64` for amounts (canonical) and ensure clients use the Protobuf JSON decoder, not a generic JSON parser.

**3. Skipping `STATUS_UNSPECIFIED = 0`**

*Why it matters:* If you start your enum at `STATUS_ACTIVE = 1`, then any message where `status` was never set (proto3 default = 0) will have an unrecognised value. Deserialisers will decode it as 0 and your switch statement will hit the default case silently.

*How to avoid:* Always define a `FOO_UNSPECIFIED = 0` enum value. buf lint will fail if you don't.

**4. Using the old `github.com/golang/protobuf` API**

*Why it matters:* `ptypes.Timestamp`, `ptypes.MarshalAny`, and friends are removed. Mixing old and new packages causes compile errors and subtle nil-pointer bugs because the two packages have separate type hierarchies.

*How to avoid:* `import "google.golang.org/protobuf/..."` everywhere. Run `go get google.golang.org/protobuf@latest` and confirm no `github.com/golang/protobuf` direct imports remain.

**5. Putting business logic in the `.proto` package path**

*Why it matters:* The Go package option and the proto package are used in generated file names and import paths. Renaming either is a breaking change for any code importing generated types.

*How to avoid:* Use a versioned, stable package path from day one: `package payments.v1;` with `option go_package = "github.com/org/repo/gen/go/payments/v1;paymentsv1";`. Add `v2`, `v3` only when you intentionally break the API.

---

## Check your understanding

1. A colleague renames a field from `user_id` to `account_id` in a deployed proto schema and regenerates the code. No field number changed. Is this a breaking change for clients compiled against the old schema? Explain the exact wire-format reason for your answer.

2. Your team wants to remove the `middle_name` field (field number 7) from a message that has been in production for six months. Write the exact proto3 syntax that makes this safe for future reuse of the schema.

3. You need an RPC that accepts a request with no meaningful payload. Which well-known type do you use as the request type, and what is its import path in the `.proto` file?
