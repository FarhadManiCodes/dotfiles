# `containers/` — rootless podman, and Postgres as a Quadlet unit

Reference for the container setup: why each decision was made, and what it was measured
against. The rules you must not break are in `AGENTS.md`; this file is the reasoning behind
them, kept out of the always-loaded document because it is needed only when one of those
decisions is reopened.

Four tracked files, all installed by `install.sh` with **no sudo** — rootless podman is
entirely user-scoped:

| Repo | Installs to |
|---|---|
| `containers/containers.conf` | `~/.config/containers/containers.conf` |
| `containers/storage.conf` | `~/.config/containers/storage.conf` |
| `containers/pg.container` | `~/.config/containers/systemd/pg.container` |
| `containers/data.network` | `~/.config/containers/systemd/data.network` |

## Why the migration off Docker happened

**Migrated 2026-09-02.** Docker put the user in the `docker` group, which is passwordless
root: `docker run -v /:/host` reads `/etc/shadow` with no prompt. That was *demonstrated*, not
theorised, before the change. It meant any code already running as the user — an AUR `build()`
during `sysup`, a PyPI package behind a `uv tool`, an AI CLI agent — could escalate silently.
Rootless podman has no such path: **no root daemon, no root socket, no group**, and every
process (`conmon`, `rootlessport`, all `postgres` backends) runs as `farhad`.

`UserNS=keep-id:uid=999,gid=999` maps the image's `postgres` user onto `farhad`, so
`/var/lib/postgres` is owned by `farhad` — **cleaner than the Docker setup**, where it belonged
to uid `999`/gid `965`, identities with no host account. This is why the earlier rejection of
*rootless Docker* (which would have needed the data chowned to subuid `100998`) does not carry
over: `keep-id` avoids the subuid mapping entirely.

`docker-compose` survives the migration (`Depends On: None`, a standalone binary) and drives
podman through the user socket via `DOCKER_HOST` in `environment.d/defaults.conf`.
`podman-docker` provides a `docker` shim that calls podman directly and needs no socket at all.

## `containers.conf` — loopback bind

Sets `default_host_ips = ["127.0.0.1"]` in the **`[network]`** section (not `[containers]`).
This replaces `/etc/docker/daemon.json`'s `"ip"` key and is better placed — a user file in the
repo instead of a root file in `/etc`. Verified: a bare `-p 5432:5432`, and a compose file with
bare `ports: ["19091:5432"]`, both bind `127.0.0.1`. That matters because compose files copied
from the internet always use the bare form.

## `data.network` — DNS between containers

Exists because **the default rootless network has no DNS between containers**. Anything that
must reach `pg` by hostname has to join this network (netavark + aardvark-dns provide the
resolution).

## Storage — the one part of the old design worth keeping

- **`@postgres` subvolume at `/var/lib/postgres`, excluded from snapper** — a btrfs snapshot of
  a running database captures a torn state.
- **`chattr +C` had to be set while the directory was empty.** The flag only applies to files
  created afterwards, so it must precede `initdb`; a database under btrfs CoW fragments badly.
  It also disables the subvolume's `compress=zstd:1` for that data, which is what you want.
  Verified still set after the migration (`lsattr -d /var/lib/postgres` shows `C`).
- Losing btrfs checksums to `nodatacow` is covered by PostgreSQL 18's own `data_checksums`,
  which is **on** — confirmed on the live instance.
- **Backups are per-database, added when a database earns one — not a default of the
  container.** Right now nothing runs `pg_dump`: no script, no unit, no timer, and the instance
  holds nothing worth keeping. An earlier version of this text asserted "backups are
  `pg_dump`", which was never true; the 2026-09-02 audit caught it. When a database does hold
  data worth keeping, add a backup unit *for that database* — a `pg_dump <db>` service plus
  timer carrying `OnFailure=notify-failure@%n.service`, shaped like the units in
  `systemd/user/`. Do not add a blanket `pg_dumpall` to the container.
- **`postgresql-libs` must stay marked `--asexplicit`.** `psql` lives in it, not in
  `postgresql`. It was installed as a dependency of the removed host server, so it is an orphan
  candidate: `pacman -Qtdq` would list it, and `sysclean --all` runs `pacman -Rns --noconfirm`
  on that list.

### `@docker` is podman's graphroot

`storage.conf` sets `graphroot = "/var/lib/docker"`, so image layers stay off `@home` — the job
the subvolume was created for, and it survives Docker's removal. `@home` is not snapshotted
today, so this is pre-emptive, but it costs nothing and means enabling home snapshots later
cannot silently start capturing the layers (**458 MB** as of 2026-09-05). The path is still
`/var/lib/docker` because that is where fstab mounts `@docker`; renaming a mountpoint risks a
boot failure for cosmetics. The name is legacy, the subvolume is not.

**The graphroot also holds the secrets.** `podman secret` stores at `<graphroot>/secrets`, so
`pg_password` lives in `/var/lib/docker/secrets`, **not** under `~/.local/share/containers`
— that path does not exist on this machine. `storage.conf` carries the same warning inline.
Moving the graphroot without moving that directory makes `pg.service` fail to start.

`install-root.sh` **chowns `/var/lib/docker` to the invoking user**. fstab mounts it root-owned
and rootless podman cannot use a graphroot it does not own; without the chown a fresh install
falls back to `~/.local/share/containers/storage` *silently* — no error, just image layers back
on `@home`.

**Do not migrate this store by moving files.** Tried on 2026-09-02 and it went badly: podman
re-initialises the store the moment `storage.conf` points somewhere new, `podman unshare`
itself refuses to run while `db.sql` records a stale static dir (`database configuration
mismatch`), and transplanting `secrets/` produces metadata whose ID the file driver cannot
resolve (`no such secret`). The working path is: stop the units, clear both locations, re-pull
images, **recreate the secret** rather than copying it.

## Why Postgres is a systemd unit, not `--restart unless-stopped`

Under Docker it was neither started at boot nor known to systemd. `docker.socket` was enabled
while `docker.service` was deliberately disabled, so the daemon only started when something
connected to the socket — and `--restart` is only honoured once the daemon runs. Measured on
2026-09-01: **139 minutes** between boot and the daemon starting, during which the "always-on"
database was simply down, until an unrelated `docker ps` woke it.

The Quadlet unit is `WantedBy=graphical-session.target`, so it now comes up with the session
alongside the `rclone@` mounts, and carries `OnFailure=notify-failure@%n.service` like every
other service here.

## The password is a podman secret, not an `Environment=` line

This repo is **public**, so a committed credential is published to the world — which is what an
`Environment=POSTGRES_PASSWORD=…` line in `pg.container` would have been. Create it once,
outside git:

```bash
podman secret create pg_password -      # type the password, then Ctrl-D
```

Be clear about what this does and does not buy: the secret store is owned by `farhad`, so any
process that can read `containers/pg.container` can equally run
`podman secret inspect --showsecret`. Against local code it is **exactly equivalent** to the
hardcoded value. It is *repo hygiene*, not a security boundary — the actual protection is the
loopback bind plus rootless isolation. `POSTGRES_PASSWORD` also only applies at `initdb`, so
rotating the secret does not change an existing database's password; use `ALTER USER` or
re-init.

## Two rootless networking facts that will bite the data pipeline

Both from `podman-rootless(7)`.

- **pasta copies the main interface's IP, so a container cannot connect to the host's own IP
  address.** Since podman 5.0 pasta is the default rootless network tool, and it clones the
  host address — so a container dialling `192.168.0.89` to reach Postgres fails, confusingly
  and with no useful error. The supported path is container-to-container by name on
  `data.network`, which is exactly why that network exists. Do not "simplify" a future pipeline
  by pointing it at the host's LAN address.
- **Published ports go through `rootlessport`, a userspace proxy that does not preserve client
  source IPs.** Everything reaching a published port looks like it came from the proxy.
  Harmless for a loopback-only database with no IP-based rules in `pg_hba.conf`, but it means
  source-IP logging, `pg_hba` host rules and any fail2ban-style tooling are all blind.

### The forwarder switch, and why it is not free

The alternative is `rootless_port_forwarder = "pasta"` in the `[network]` section of
`containers.conf` — kernel-level forwarding via pasta's control socket, which preserves the
client IP. `pasta` is present (`/usr/bin/pasta`, a symlink to `passt`, package `passt`
`2026_07_28`), so the mechanism is available today. Two caveats `containers.conf(5)` states
that are easy to miss: the option is **experimental and subject to change**, and `pasta` is the
only valid value for `default_rootless_network_cmd` anyway.

**Do not flip that switch before fixing `pg_hba.conf`, or you silently turn off password
authentication.** The postgres image ships `pg_hba` with `host all all 127.0.0.1/32 trust` and
`::1/128 trust` above the catch-all `host all all all scram-sha-256`, and `pg_hba` is
first-match-wins. The image can assume those `trust` lines are safe because nothing outside the
container reaches `127.0.0.1` *inside* it. Today that holds: `rootlessport` rewrites the source,
so host connections arrive from the container network gateway, fall through to the scram line,
and are asked for a password — confirmed in the journal, which logged
`Connection matched ... line 128: "host all all all scram-sha-256"`. Preserve source IPs and a
host connection to `127.0.0.1:5432` matches the `trust` line **first** and gets in with no
password.

So the missing source-IP preservation is currently load-bearing, not a wart. Correct order if
it is ever needed: replace those two `trust` lines with `scram-sha-256`, *then* change the
forwarder. (`podman exec pg psql` works without a password for the same reason — it genuinely
originates at `127.0.0.1` inside the container's netns. That is what was used to reset the
password on 2026-09-02.)

## `runc` is kept over `crun` deliberately

podman's shipped `containers.conf` documents `#runtime = "crun"` as its default, so every audit
will flag the deviation. The deciding fact is not size:

> `podman-rootless(7)`, *Shortcomings of Rootless Podman*: "`podman container checkpoint` and
> `podman container restore` (**CRIU requires root**)"

On Arch, `crun` **hard-depends on `criu`** (optional upstream, enabled in Arch's build), and
criu exists to serialise process state via Protocol Buffers — so it drags in `protobuf`
(18.89 MiB), `python-protobuf`, `protobuf-c` and `libnet`. That is ~27 MiB of dependency whose
only purpose is checkpoint/restore, which podman documents as **non-functional in rootless
mode** — the only mode used here. Not merely unused: unusable.

Numbers, for completeness: `runc` (8.65 MiB) + `libpathrs` (4.63 MiB) = **13.28 MiB across 2
packages** (nothing else needs either); the crun stack is 28.20 MiB across 6. crun's genuine
advantages — ~2× faster cold start, lower per-container memory — apply to container-dense
workloads, not to one long-lived database. `runc 1.5.1` (spec 1.3.0) handles cgroups v2
correctly here (delegation and live accounting both verified) and podman reports no warnings.
`runc` cannot be removed while it is the only `oci-runtime` provider — `pacman -Rsp runc`
refuses, since podman requires one.

**Pinned since 2026-09-09**, in `containers.conf` under `[engine]`. Until then the decision
above was enforced by nothing but crun's absence: crun declares `Provides: oci-runtime` and
podman declares `Depends On: oci-runtime`, so either satisfies podman, and podman's shipped
config documents `#runtime = "crun"` as its default. Anything installing crun would have moved
the running database to a different runtime with no error and no warning. The pin is read —
verified by pointing `CONTAINERS_CONF` at a copy naming a bogus runtime, which podman rejects
outright. The trade is deliberate: if runc ever goes missing podman now refuses rather than
silently substituting. No `config-drift` check accompanies it, because the pin turns a silent
substitution into a loud failure that announces itself.

## No `registries.conf`, deliberately

There is none in `/etc/containers/`, none in `~/.config/containers/`, and none tracked here.
That is the shipped state, not a gap: `containers-common` installs its copy at
`/usr/share/containers/registries.conf` and deliberately puts nothing in `/etc`. Recorded
because an audit that finds a missing file tends to want to add one, and here that would be a
downgrade.

What the absence buys is that podman never *searches* for an image. A short name resolves only
through the curated alias table at `/usr/share/containers/registries.conf.d/00-shortnames.conf`
— 132 entries, each mapping one name to exactly one fully-qualified image (`alpine` →
`docker.io/library/alpine`). Anything not in that table fails loudly rather than being guessed
at:

```
$ podman pull definitely-not-a-real-image-xyz
Error: short-name "definitely-not-a-real-image-xyz" did not resolve to an alias
and no containers-registries.conf(5) was found
```

`postgres` is not one of the 132, which is why `pg.container` names
`docker.io/library/postgres:18` in full — the right habit regardless.

**The tempting addition is the one to avoid.** `unqualified-search-registries = ["docker.io"]`
would make short names convenient by reintroducing exactly the guessing this avoids: any typo
or lookalike name would resolve somewhere rather than erroring. The safe alternative, an empty
search list, is what already happens. So the correct amount of configuration here is none, and
images stay fully qualified in Quadlets.

## `pg.container` — the settings that are less obvious than they look

**`DefaultDependencies=false` in the `[Quadlet]` section is load-bearing.** Quadlet otherwise
injects `Wants=`/`After=podman-user-wait-network-online.service` into every generated unit, and
that helper polls `systemctl is-active network-online.target`. This machine never reaches that
target — `systemd-networkd-wait-online` is masked on purpose for boot speed, and nothing else
activates it. So the helper polled for 90 s, timed out, and left a **permanently failed unit**,
which is corrosive: `systemctl --user --failed` is the remote health check, and a unit that
always fails trains you to ignore it. It also delayed Postgres by the full timeout — 90 of the
108 seconds between boot and `pg` on 2026-09-02. Note the key goes in `[Quadlet]`, **not**
`[Unit]`, where the same name means something else entirely.

Three more, all wrong in the first draft:

- **`StopTimeout=60`, not `[Service] TimeoutStopSec`, is the real shutdown deadline.** The image
  sets `StopSignal=SIGINT` (postgres "fast shutdown"), but *podman* kills the container after
  its own `StopTimeout`, which defaults to **10 s** — regardless of what systemd was told. A
  generous `TimeoutStopSec` alone is therefore a false comfort. `podman-systemd.unit(5)` says
  podman's value should stay below the systemd one, so it is 60 under 120.
- **`Notify=healthy` + `HealthCmd`.** Without them systemd calls the unit started the moment
  the container process launches, not when Postgres accepts connections — so anything ordered
  `After=pg.service` would race it. With them, `systemctl --user start pg` returns only once
  `pg_isready` passes. Matters as soon as a second container talks to this one.
- **`HealthOnFailure=kill`.** The default is `none`, meaning a Postgres that is alive but wedged
  (accepting no connections) would never restart *and never fire `OnFailure=`* — a silent
  failure, the exact thing the notification design exists to prevent. `kill` makes podman kill
  the container, systemd's `Restart=on-failure` restart it, and a persistent failure reach
  `notify-failure@`.

## Updates

There is deliberately no `AutoUpdate=` — a surprise postgres major bump needs `pg_upgrade` and
would fail against an older data directory. But nothing else refreshed these images either, so
`sysup` gained a `_sysup_podman_images` step: it pulls the images of running containers and
**restarts the owning Quadlet unit when a digest changed**. The restart is the part that is easy
to omit and silently pointless without — a pull alone leaves the old layers in use. Tags pin the
major version, so a pull only brings minor/patch updates.
