# Day 44 Lab: Teardown

## Cleanup

The smoke test doesn't leave any persistent state. To clean up:

```bash
# From labs/phase3/day43/ (if you want to stop services)
docker compose down

# Or just leave the containers running for day45
```

## No Files Generated

Unlike some labs, the smoke test doesn't create files in the lab directory. All output is printed to stdout. If you want to save the output:

```bash
bash smoke_test.sh | tee smoke_test_output.log
```

This captures the test output in `smoke_test_output.log` for later review.

## If Services Are Still Running

You can run the smoke test multiple times without restarting services. Just re-run:

```bash
bash smoke_test.sh
```

Each run creates a new API and application in the CP, so you can run it repeatedly to verify stability.

