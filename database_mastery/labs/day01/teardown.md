# Day 1 teardown

Nothing to tear down. Day 1 only reads the catalogs — it created no
tables, no data, and no state that needs cleaning up before Day 2, which
reuses this same seeded stack (`wide_payments` is Day 2's starting
artifact, already loaded).

Leave the stack running between sessions:

```bash
docker compose -p dbmastery stop
```

This stops the containers without touching their volumes — safe any time,
and the fastest way back in is `docker compose -p dbmastery start`
followed by re-entering `ws`.

Do **not** run `docker compose -p dbmastery down -v` unless you actually
want to discard the seeded dataset. `-v` deletes the named volumes
(`pgdata`, `pgarchive`, `mydata`, `mongodata`), which costs a full re-seed
(`labs/stack/seed/README.md` — roughly 15 minutes at `SCALE=10`) before
Day 2 or any later day will work again.
