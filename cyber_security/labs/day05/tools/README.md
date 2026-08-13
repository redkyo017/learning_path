# `linpeas.sh` — download note (not vendored)

This lab intentionally does **not** vendor a copy of `linpeas.sh` in the repo: the
real script (from the [PEASS-ng](https://github.com/peass-ng/PEASS-ng) project) is a
single multi-hundred-KB file that changes often upstream, and committing a stale copy
would silently drift from the actual tool anyone downloads today. Instead, fetch it
fresh, once, into the shared loot directory, from the already-running `attacker`
container (it has `curl` and outbound network access; `target` does not need either):

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "
mkdir -p /loot/day05
curl -sL -o /loot/day05/linpeas.sh https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh
chmod +x /loot/day05/linpeas.sh
echo DOWNLOADED
"
```

`/loot` is the same host directory (`labs/base/loot/`) that `labs/day05/docker-compose.yml`
bind-mounts into `target` too — so the moment this finishes, `/loot/day05/linpeas.sh`
is already visible and executable **inside `target`** as well, with no extra copy
step. See [`../README.md`](../README.md) "Setup" for where this fits in the full
sequence.

**No internet in your environment?** `linpeas.sh` is not required to complete this
lab — every planted vector is fully enumerable by hand with commands this lab's
content file and README already give you (`find / -perm -4000 -type f 2>/dev/null`,
`sudo -l`, `ls -la /etc/cron.d/ /opt/scripts/`). Treat `linpeas.sh` as a convenience
that automates and cross-checks manual enumeration, not a dependency — exactly the
role it plays on a real engagement, where you may not always have outbound network
access from the box you've landed on either.
