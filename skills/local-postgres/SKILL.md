---
name: local-postgres
description: >
  Connect to and work with the PostgreSQL database running on this machine. Use when you need
  to run a query, inspect schemas or tables, use psql or a database URL, set DATABASE_URL or a
  dadbod connection, load or export data, or when the pg container or pg.service is failing or
  refusing connections. Covers where the credential lives, why a password is required despite
  the image trusting localhost, and how to start and stop it correctly.
---

# The local PostgreSQL

Postgres runs as a **rootless podman container** managed by a systemd user unit (`pg.service`,
generated from a Quadlet file). It listens on `127.0.0.1:5432` only.

## Connecting

A password **is** required, and it lives in a podman secret rather than a file or an
environment variable:

```bash
PGPASSWORD="$(podman secret inspect --showsecret --format '{{.SecretData}}' pg_password)" \
  psql -h 127.0.0.1 -U postgres -d postgres
```

**Never echo, print, log or write that value.** Substitute it directly into `PGPASSWORD` (or a
URL you do not print) as above. It is the real credential for the user's database.

For a connection URL — the same rule applies, do not print the assembled string:

```bash
export DATABASE_URL="postgresql://postgres:$(podman secret inspect --showsecret \
  --format '{{.SecretData}}' pg_password)@127.0.0.1:5432/postgres"
```

### Why the password is needed even though the image trusts localhost

The `postgres` image ships `trust` lines for `127.0.0.1` in `pg_hba.conf`, so it looks as
though a local connection should need no password. It does need one, because
**`rootlessport` rewrites the source address** — the connection arrives at postgres from the
container network's gateway, not from loopback, so it never matches the trust rule and falls
through to `scram-sha-256`. Confirmed by observation: connecting without a password fails with
`fe_sendauth: no password supplied`.

This is also why `rootless_port_forwarder` must not be switched to `pasta` without fixing
`pg_hba.conf` first: pasta preserves source addresses, which would make those `trust` lines
match and silently disable password authentication.

## What is actually in there

Do not assume. Ask:

```bash
PGPASSWORD=... psql -h 127.0.0.1 -U postgres -d postgres -tAc \
  "select datname from pg_database where not datistemplate"
```

Documentation elsewhere in this repo refers to a `dev_db`; check before relying on it.

## Starting, stopping, and status

**Lifecycle is systemd, not podman.** `podman stop pg` gets the container restarted by systemd
and looks like a container refusing to die.

```bash
systemctl --user status pg.service
systemctl --user restart pg.service
journalctl --user -u pg.service -n 50
podman ps            # fine for inspection
```

**Never `sudo podman`.** That uses a separate root-owned store in `/var/lib/containers`. If
`sudo podman ps` is empty while `podman ps` shows `pg`, that is the reason and not a fault.

## "Started" does not mean "accepting connections"

The unit declares `Notify=healthy` with a `pg_isready` healthcheck, so systemd holds the unit
*activating* until postgres actually answers. That is deliberate — anything ordered
`After=pg.service` would otherwise race a container that has launched but is still recovering.
`HealthStartPeriod` allows a minute for that.

So a connection refused immediately after a restart is usually not an error; check the unit
first:

```bash
systemctl --user show pg.service -p ActiveState,SubState --value
podman healthcheck run pg && echo healthy
```

A container that is alive but wedged gets killed and restarted by `HealthOnFailure=kill`, and
`OnFailure=notify-failure@` records it to `~/.local/state/service-failures/failures.log`.

## If it will not start

The most common cause is the missing secret — the unit fails loudly rather than silently:

```bash
podman secret ls | grep pg_password || echo "create it: podman secret create pg_password -"
```

Note `POSTGRES_PASSWORD` only applies at **initdb**. Changing the secret afterwards does not
change an existing database's password, so a rotated secret and an existing data directory
means authentication failures, not a fresh password.

## Backups

There are none, deliberately — no `pg_dump` runs anywhere, and the `@postgres` btrfs subvolume
is excluded from snapper because a snapshot of a live database is a torn state. If you are
about to create data worth keeping, say so rather than assuming it is protected.
