# Day 13 Lab — proto evolution over gRPC (back-compat, then break it)

Two Go services talk gRPC. You will (A) run a baseline call, (B) evolve the proto
**additively** and prove nothing breaks, then (C) **break it** by renumbering a
field and watch the value silently vanish at the wire.

No docker needed today — this is two local Go processes plus `buf`.

## Prereqs (Beat 0)

```bash
brew install bufbuild/buf/buf
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
export PATH="$PATH:$(go env GOPATH)/bin"   # so buf finds the plugins
buf --version && protoc-gen-go --version
```

Work from this `lab/` directory for every command below.

## Step A — baseline: generate, wire it up, make one call

```bash
buf lint                     # proto passes STANDARD lint
buf generate                 # writes gen/order/v1/order.pb.go + order_grpc.pb.go
go mod tidy                  # populate go.sum (needs network once)

go run ./server &            # inventory listens on :50051
sleep 1
go run ./client -sku SKU1 -qty 3    # -> available=true  on_hand=10
go run ./client -sku SKU2 -qty 1    # -> available=false on_hand=0
go test ./compat/                   # -> PASS (baseline wire reads quantity=5)
```

Expected: the SKU1 call returns `available=true`, SKU2 returns `available=false`,
and the compat test passes. Leave the server running.

## Step B — additive evolution (back-compat holds)

1. In `proto/order/v1/order.proto`, **uncomment** `string warehouse = 4;`.
2. Regenerate and rebuild **both** binaries:
   ```bash
   buf generate
   # restart the server so it runs the new code
   kill %1 2>/dev/null; go run ./server &
   sleep 1
   go run ./client -sku SKU1 -qty 3   # still works: client sends no warehouse
   go test ./compat/                  # still PASS: field 3 unchanged
   ```
3. Observe: the old-shaped call and the captured baseline wire bytes **still work**.
   New field 4 is simply absent from old data; proto3 defaults it to `""`. Adding a
   field is backward *and* forward compatible.
4. (Optional insight — the TODO in `server/main.go`) make stock per-warehouse and
   select it from `req.GetWarehouse()`, treating `""` as the default warehouse so
   old callers keep working.

`buf` can also *prove* your change is safe before you ship:
```bash
git stash -- proto/  ; buf breaking --against '.git#branch=HEAD'  # (if under git) -> no breaking changes
```

## Step C — BREAK IT: renumber a field (the mandatory break-it)

1. In the proto, change `int32 quantity = 3;` to `int32 quantity = 7;`. Regenerate:
   ```bash
   buf generate
   go test ./compat/
   ```
2. **Observe the silent break.** The test fails with `quantity = 0, want 5`. The
   captured wire bytes still carry field 3 (`0x18 0x05`); the new struct looks for
   field 7 (`0x38`), treats field 3 as an unknown field, and defaults quantity to
   `0`. **No error is raised** — an old client and new server would just process
   every order as quantity 0.
3. Confirm it's a wire-tag mismatch, not a bug in your code:
   ```bash
   # decode the raw baseline bytes with no schema:
   printf '\x0a\x02o1\x12\x04SKU1\x18\x05' | protoc --decode_raw
   # -> shows "3: 5" — field 3 that the renumbered schema no longer maps to quantity
   ```
4. **Fix:** restore `quantity` to field `3`. If you truly needed to retire a field,
   the correct move is `reserved 3; reserved "quantity";` and add the replacement at
   a *new* number — never reuse or renumber.

## Teardown

```bash
kill %1 2>/dev/null   # stop the server
```

Record everything in `results.md`.
