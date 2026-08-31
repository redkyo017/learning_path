# Day 15 Lab — Teardown

## Stop the Key Manager

If running with `go run main.go`, press `Ctrl+C` in terminal 1.

If running in the background:

```bash
kill $(lsof -ti:9444)
```

## Clean up log file

```bash
rm -f /tmp/km.log
```

## Remove Go module files (optional)

If you want to reset the directory to a clean state:

```bash
cd labs/phase1/day15
rm -f go.mod go.sum
```

This does not affect `main.go` or `playbook.md`.

## Phase 1 complete

No Docker containers were started in this lab.  No databases, no persistent state.
The in-memory client registry and token store are gone when the process exits.

Well done — Phase 1 is complete.
