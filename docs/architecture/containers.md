# Containers — rootless podman, and Postgres as a Quadlet unit

**Migrated off Docker 2026-09-02** — the `docker` group is passwordless root (proof and
full reasoning in `containers/README.md`). Rootless podman has **no root daemon, no root
socket, no group**; the rules are here, the post-mortems there.

Four tracked files, all installed by `install.sh` with **no sudo**:

| Repo | Installs to |
|---|---|
| `containers/containers.conf` | `~/.config/containers/containers.conf` |
| `containers/storage.conf` | `~/.config/containers/storage.conf` |
| `containers/pg.container` | `~/.config/containers/systemd/pg.container` |
| `containers/data.network` | `~/.config/containers/systemd/data.network` |

Three ways to get this wrong:

- **Never `sudo podman`.** It uses a separate root-owned store in `/var/lib/containers`.
  If `sudo podman ps` is empty while `podman ps` shows `pg`, that's why — not a bug.
- **Never enable the *system* `podman.socket`.** That recreates a root-owned socket at
  `/run/podman/podman.sock`, which `podman-docker` has already symlinked
  `/var/run/docker.sock` to — rebuilding exactly the escalation path this migration
  removed. The **user** socket (`$XDG_RUNTIME_DIR/podman/podman.sock`) is the safe one.
- **Lifecycle is `systemctl --user`, not `podman`.** `pg` is a Quadlet unit, so
  `podman stop pg` just gets it restarted by systemd.

And seven things not to "fix", each explained in `containers/README.md`:

- **`runc` over `crun` is deliberate** — crun hard-depends on `criu` on Arch (~27 MiB)
  for checkpoint/restore, which podman documents as non-functional rootless.
- **`DefaultDependencies=false` belongs in `[Quadlet]`, not `[Unit]`** — without it
  Quadlet injects a wait on `network-online.target`, which this machine never reaches: a
  permanently failed unit and 90s of delay.
- **Don't flip `rootless_port_forwarder` to `pasta` before fixing `pg_hba.conf`** — the
  image's `trust` lines for `127.0.0.1` are only safe because `rootlessport` rewrites the
  source address; preserving source IPs silently turns off password authentication.
- **Don't point a container at the host's LAN IP** — pasta clones the host address, so it
  can't work; use container-to-container names on `data.network`.
- **Don't migrate the store by moving files** — stop the units, clear both locations,
  re-pull, and recreate the secret.
- **Podman's helper scopes are ordered `Before=pg.service`** — the drop-ins in
  `systemd/user/*-.scope.d/` stop pg before pasta, aardvark-dns and the pause process at
  shutdown; a new container's unit goes on the same `Before=` line.
- **`postgresql-libs` must stay `--asexplicit`** — `psql` lives in it and is otherwise an
  orphan candidate `sysclean --all` would remove.

`pg` needs a secret before it will start; podman stores it under the graphroot, at
`/var/lib/docker/secrets`:

```bash
podman secret create pg_password -      # type the password, then Ctrl-D
```

Backups are **per-database, added when a database earns one** — nothing runs `pg_dump`
today, and a blanket `pg_dumpall` doesn't belong in the container. There is deliberately
no `AutoUpdate=`; `sysup`'s `_sysup_podman_images` step pulls and restarts the owning
unit instead.
