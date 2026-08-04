# TODO — actions that need me, not the config

Left over from the 2026-07/08 config audit. Each item is something no script in this
repo can do: it needs a browser, a decision, or root. Delete an entry once it's done.

For issues that were investigated and **accepted** (nothing to do), see `revisit.md`.

---

## 1. Push the audit — no sudo

58 commits sit unpushed on `master`. Everything else below assumes these are in.

```bash
cd ~/dotfiles && git push
```

---

## 2. rclone: replace the Google Drive `client_id` — no sudo, needs a browser

`~/.config/rclone/rclone.conf` has **no `client_id`**, so both remotes use rclone's
built-in one. That client is shared by every rclone user on earth and its Google API
quota is permanently exhausted — this is the root cause of the sync failures, not the
logging. Google also began throttling the shared client harder during 2026.

Fix: create a personal OAuth client (free, 10 min, no billing account).

1. https://console.cloud.google.com → new project
2. **APIs & Services → Library** → enable *Google Drive API*
3. **OAuth consent screen** → External → add your own email as a test user
4. **Credentials → Create credentials → OAuth client ID → Desktop app**
5. `rclone config` → edit each Drive remote → paste `client_id` + `client_secret`
   → re-authorise when prompted

Verify: `systemctl --user start rclone@<remote>` then
`journalctl --user -u rclone@<remote> -n 30` — no 403 `userRateLimitExceeded`.

The service already notifies on failure (`notify-failure@`), so a silent breakage
can't recur — but the quota problem itself is only fixable here.

---

## 3. Reclaim ~2.7 GB — no sudo

Plain `sysclean` frees nothing (already clean). The space is all in the pacman
package cache, which needs the deep pass:

```bash
sysclean --all
```

Current: pacman cache 2.7 G, uv cache 83 M, paru cache 1.3 M.

This is **not** neglect — `paccache.timer` is enabled and prunes automatically. 2.7 G is
just the steady state at its default `-k3` (three versions of every package kept). If
you'd rather it stayed small on its own, drop it to one version via a drop-in:

```bash
sudo systemctl edit paccache.timer   # or override PACCACHE_ARGS in the service
```

---

## 4. AOCL: one symlink to silence the linker — needs sudo

Every C++ link against `-llapack` prints:

```
ld: warning: libaoclutils.so, needed by /usr/lib/liblapack.so, not found
```

`liblapack.so` (AOCL libFLAME) records **absolute** `DT_NEEDED` paths, so programs
*run* fine — but `/opt/aocl` is on no linker search path, so `ld` can't resolve the
transitive dependency. Cosmetic today; a hard error under `--no-allow-shlib-undefined`.
Arguably a packaging bug in `blas-aocl-gcc`, which symlinks `libblas`/`liblapack` into
`/usr/lib` but not `libaoclutils`.

```bash
sudo ln -s /opt/aocl/gcc/lib_LP64/libaoclutils.so /usr/local/lib/libaoclutils.so
```

Then verify — expect **no output**:

```bash
printf 'int main(void){return 0;}\n' > /tmp/t.c && gcc /tmp/t.c -o /tmp/t -llapack
```

Why `/usr/local/lib` and not `ld.so.conf.d`:

- it is on `ld`'s default `SEARCH_DIR` list, so link-time resolution works
- it is **not** on the runtime loader path, and it is outside pacman's territory
- adding `/opt/aocl/gcc/lib_LP64` to `/etc/ld.so.conf.d/` instead would put AOCL's
  `libfftw3.so.3` ahead of the system `/usr/lib/libfftw3.so.3.7.11` for **every**
  FFTW consumer on the machine (same soname, different build). Don't.

Verified: `libaoclutils.so` is the only missing library, and one symlink in a searched
directory is sufficient. `-L` / `LIBRARY_PATH` cannot fix it — `ld` does not search
those for indirect dependencies.

If the symlink somehow doesn't take, the no-sudo fallback is a line in `zsh/.zshenv`
(verified to work for both plain `gcc` and CMake, and it does not shadow `-lfftw3`):

```zsh
export LDFLAGS="-Wl,-rpath-link,/opt/aocl/gcc/lib_LP64"
```

---

## 5. ~~tmux-resurrect: verify~~ — DONE 2026-08-03, works

Tested end to end on an isolated socket: save → kill-server → restore brought back the
session, all window names, pane counts and splits, working directories, captured pane
contents, **and** restarted `btop` as a live process from `@resurrect-processes`. Keep
the plugin. Nothing to do.

One gotcha if it ever looks broken: a pane spawned *as* a command
(`new-window -n mon 'btop'`) records an empty full-command and is **not** restored —
only panes where the program was started from a shell are. Normal use is unaffected.

---

## 6. Remove the `postgresql` server — needs sudo

66 MiB, service **disabled**, and `/var/lib/postgres/data` is **empty** — `initdb` was
never run, so the server has never been used. The `psql` client you actually use comes
from **`postgresql-libs`**, a separate package that stays:

```bash
pacman -Qoq /usr/bin/psql     # → postgresql-libs, not postgresql
sudo pacman -Rs postgresql
```

---

## 7. Enable `smartd` for disk-health monitoring — needs sudo

`smartmontools` is installed but `smartd.service` is **disabled**, so nothing watches
SMART attributes. This was the only real configuration gap found across all 177
explicitly-installed packages.

```bash
sudo systemctl enable --now smartd.service
systemctl status smartd            # confirm it found the NVMe
```

Stock `/etc/smartd.conf` (`DEVICESCAN`) is fine to start with. If you want failures to
reach you the same way service failures do, add
`OnFailure=notify-failure@%n.service` — but note `notify-failure@` is a **user** unit
and `smartd` is system-level, so it would need a system-level equivalent of
`bash/service-failed-notify`. Worth doing only if you want the symmetry.

---

## 8. Make Docker actually usable — decided: KEEP — needs sudo

Decision made 2026-08-03: keep it (217 MiB — `docker` 114 + `docker-buildx` 62 +
`docker-compose` 28 + `lazydocker` 13). But right now it is installed and **not usable**:

- `docker.service`, `docker.socket`, `containerd.service` — all **disabled**
- you are **not in the `docker` group** (the group exists, gid 968), so every command
  needs `sudo docker`
- no `~/.docker`, no `~/.config/lazydocker` — both use built-in defaults

To make it work on demand without a boot-time daemon, enable the **socket**, not the
service — dockerd then starts on first use and stays out of the way:

```bash
sudo systemctl enable --now docker.socket
```

Group membership is the other half, and it is a **real privilege decision, not a
formality**: the `docker` group is equivalent to passwordless root, because anyone in it
can `docker run -v /:/host` and edit the host filesystem as root. Three options, pick one:

1. **Stay out of the group**, use `sudo docker` — no privilege escalation, mildly annoying.
2. **Join the group** — convenient, and accepts that `docker` == root on this machine:
   ```bash
   sudo usermod -aG docker farhad    # then log out and back in
   ```
3. **Rootless Docker** — keeps convenience without the root-equivalence:
   ```bash
   dockerd-rootless-setuptool.sh install
   systemctl --user enable --now docker    # then DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
   ```
   Fits this setup best, given Apptainer was already chosen for unprivileged containers.

Nothing needs to be added to this repo either way — `lazydocker`'s defaults are fine, and
a config only becomes worth tracking once you've customised it.
