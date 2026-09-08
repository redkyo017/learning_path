# ws: the learner's workbench container. Every lab command in this course
# runs inside this container via `docker compose -p dbmastery exec ws bash`.
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# postgresql-16-repack ships pg_repack's CLIENT binary (the server-side
# extension itself lives inside the `pg` container image and is enabled by
# a lab's setup step); installing this package here gives `ws` the
# `pg_repack` CLI that talks to it over the network.
#
# postgresql-16 (the actual server package, not postgresql-client-16) is
# what really provides the `pgbench` binary on Debian/PGDG. postgresql-16
# -repack above already pulls the full server package in transitively (it
# hard-depends on it), which is how pgbench would end up on PATH even
# without listing it — but relying on that silently is fragile (it can
# stop being true if repack's dependencies ever change) and undocumented.
# Listed explicitly here so pgbench keeps working on its own merits and
# the reason it's present is on record, not an accident of another
# package's dependency graph.
#
# Single RUN instruction (one image layer) that: bootstraps the minimal
# tools needed to add third-party apt repos, adds the PGDG repo (Debian
# bookworm's own repo only ships PostgreSQL 15, and we need the 16 client
# to match the `postgres:16` server) and the MongoDB repo (mongosh and
# mongodb-database-tools are not packaged in Debian at all), then installs
# everything the labs need in one apt-get invocation, and finally cleans
# up the apt lists so they don't bloat the image.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg; \
    install -d /usr/share/keyrings; \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
      | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list; \
    curl -fsSL https://pgp.mongodb.com/server-7.0.asc \
      | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg] https://repo.mongodb.org/apt/debian bookworm/mongodb-org/7.0 main" \
      > /etc/apt/sources.list.d/mongodb-org-7.0.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        postgresql-client-16 \
        postgresql-16 \
        postgresql-16-repack \
        default-mysql-client \
        curl \
        ca-certificates \
        gnupg \
        jq \
        python3 \
        bash \
        less \
        procps \
        mongodb-mongosh \
        mongodb-database-tools; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /work
