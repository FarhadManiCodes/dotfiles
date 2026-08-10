# TODO — actions that need me, not the config

Left over from the 2026-07/08 config audit. Each item is something no script in this
repo can do: it needs a browser, a decision, or root. Delete an entry once it's done.

For issues that were investigated and **accepted** (nothing to do), see `revisit.md`.
For what was changed and why, across all repos, see `AUDIT-2026-08.md`.

## Suggested order

Section numbers below are historical (they grew as findings landed) — this is the order
worth doing them in.

| Do | Item | Needs | Why this order |
|---|---|---|---|
| 1 | **4** — AOCL symlink | sudo, 1 line | Removes a warning from every C++ link. |
| 2 | **6** — remove `postgresql` | sudo, 1 line | 66 MiB, never initialised. |
| 3 | **7** — enable `smartd` | sudo, 1 line | Only real config gap in 177 packages. |
| 4 | **8** — make Docker usable | sudo + a privilege decision | Needs you to choose group vs rootless. |
| 5 | **6b** — packaged `mutool` | sudo | Replaces a hand-dropped binary that gets no updates. |
| 6 | **3** — `sysclean --all` | sudo | Reclaims 2.7 GB; purely optional, `paccache.timer` already manages it. |
| 7 | **9** — `sysclean` `--noconfirm` | a decision | Latent, not active. Read before changing. |

Done: **1** (both repos pushed), **1b** (`SpackStream` on GitHub, 2026-08-09),
**2** (rclone own client_id, 2026-08-09), **5** (tmux-resurrect verified),
**5b** (`Alt+n` in real sioyek, 2026-08-10 — found two placeholder bugs).

Items 4, 6, 7 and 6b are four independent `sudo` one-liners and could be done in one
pass. Only **8** and **9** need a decision from you.

Everything left is either one `sudo` line, or a decision only you can make. Nothing on
this list is broken.

---

## 1b. ~~`projects/SpackStream` has no git remote~~ — DONE 2026-08-09

Now at `github.com/FarhadManiCodes/SpackStream`, **private**, default branch `main`,
both commits on the remote (`83ebbe0`), local == remote, clean tree. Private chosen
deliberately: the goal was getting it off a single disk, and private → public stays a
one-command decision later, whereas public → private does not undo clones or indexing.

Scanned before publishing, in case it is ever made public: no secrets, no personal email
(commits use the GitHub `noreply` address), and the only institutional references
(`fritz.nhr.fau.de`, `hpc.fau.de`, `/home/{hpc,vault,woody}`, module names) are all
publicly documented by NHR@FAU.

Everything in `~/projects` now has a remote and is pushed.

---

## 2. ~~rclone: replace the Google Drive `client_id`~~ — DONE 2026-08-09

`gdrive` now uses a personal OAuth client (GCP project `rclone-personal`, Desktop app,
published). Verified after the reconnect: `client_id`/`client_secret` written, token hash
changed, the `NOTICE: ... shared Google Drive client_id` line **gone** from
`rclone about gdrive:`, mount serving real file contents at `~/Cloud/gdrive`, and
`study-library-sync.service` run manually → `Result=success`.

Procedure and the four traps are in `CLAUDE.md` under "rclone — Google Drive uses a
personal OAuth client", in case a Drive or Photos remote is ever added. `Dropbox` still
uses rclone's shared client, deliberately: the retirement covers Drive and Photos only.

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

## 5b. ~~Press `Alt+n` in sioyek once~~ — DONE 2026-08-10, and it found two bugs

Worth having done: the keypress was the one untested seam, and **both things it could
have got wrong, it had**. Neither was detectable from the harness, which supplies argv
directly instead of letting sioyek build it.

1. **`%{current_page_label}` is not a command placeholder.** sioyek substitutes it only
   into the status-bar format string (`main_widget.cpp:1441`); the command list
   (`:4188`–`4270`) omits it, so it arrived as the literal text `%{current_page_label}`
   and appeared in a note heading.
2. **`%{page_number}` is 0-based in commands** — `:4210` passes
   `get_current_page_number()` raw while the status bar renders it `+ 1` (`:1440`). A
   capture on page 7 recorded page 6.

Fixed by dropping the label placeholder and adding the `+1` in the script; the marker now
stores the 1-based page, which is also what `goto_page_with_page_number` wants
(`input.cpp:3587` does `stoi(text) - 1`). Full list of valid placeholders is in
`sioyek/README.md` — anything not on it passes through silently.

Verified on a real capture (Kalman 1960, p.7): `## p.7`, marker `page=7` with no `label=`
field, no literal `%{` anywhere, quote fenced 1/1, and `indexable_prose` reducing 2260
chars to 1277 — quote and markers stripped, heading kept, prose intact.

Still unspent: a live `pask index` of the note (costs embedding quota). The offline path
is proven; that would only confirm the `@Kalman_1960 (note)` source marker end to end.

---

## 6b. Replace the hand-installed `mutool` with the packaged one — needs sudo

`~/.local/bin/mutool` is a 43.8 MiB binary hand-placed on 2026-05-24, owned by no
package, and it is the only `mutool` on this system. It is genuinely used — the PDF notes
in `CLAUDE.md` rely on it (keeps bookmarks, drops links, unlike `qpdf`) — but a
hand-dropped binary gets no security updates and no soname tracking.

Arch ships it in `mupdf-tools`, which links the shared mupdf libraries instead of
bundling them:

```bash
pacman -Si mupdf-tools            # check size first
sudo pacman -S mupdf-tools
rm ~/.local/bin/mutool            # then confirm: command -v mutool -> /usr/bin/mutool
mutool -v
```

Also unaccounted for in `~/.local/bin`: **`agy`, 172 MiB** (an AI CLI agent, v1.1.0,
placed 2026-07-08) and **`~/.local/share/sioyek/sioyek`, 46 MiB**. Both hand-installed
and owned by no package. Not defects — just know they exist and get no updates.

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

---

## 9. `sysclean --all` removes orphans unattended — your call

`zsh/functions/sysclean.zsh:56`:

```zsh
sudo pacman -Rns "${orphans[@]}" --noconfirm
```

This does both of the things you have said not to do: `--noconfirm`, and running
`sudo pacman` without you seeing it. `-Rns` also strips config files, on whatever
`pacman -Qtdq` happens to return that day.

**The risk is latent, not active.** `-Qtdq` returns nothing right now, and it only lists
packages installed *as dependencies* — so `aocl-gcc` and `blas-aocl-gcc` are safe despite
showing `Required By: None`, because both are **explicitly installed**. But the first time
something does appear there, it is removed without being shown to you.

Suggested change: print the list, drop `--noconfirm`, let it be a decision.

Also dead code in the same function: lines 44/46 (`pacman -Sc/-Scc --noconfirm`) are
unreachable — `paccache` is installed, so the `paccache` branch always wins.

Left alone deliberately: it is your script, and changing what a cleanup tool deletes is
not something to do on someone's behalf.
