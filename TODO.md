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
| 1 | **6b** — packaged `mutool` | sudo | Replaces a hand-dropped binary that gets no updates. |
| 2 | **3** — `sysclean --all` | sudo | Reclaims 2.7 GB; purely optional, `paccache.timer` already manages it. |
| 3 | **9** — `sysclean` `--noconfirm` | a decision | Latent, not active. Read before changing. |

Done: **1** (both repos pushed), **1b** (`SpackStream` on GitHub, 2026-08-09),
**2** (rclone own client_id, 2026-08-09), **4** (AOCL symlink, 2026-08-10),
**5** (tmux-resurrect verified), **5b** (`Alt+n` in real sioyek, 2026-08-10 — found two
placeholder bugs), **6** (`postgresql` → container, 2026-08-10),
**7** (decided: no smartd on NVMe), **8** (Docker socket + group, 2026-08-10).

Three items left. Only **9** genuinely needs you; the other two are optional tidying.
Nothing on this list is broken.

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

## 4. ~~AOCL: one symlink to silence the linker~~ — DONE 2026-08-10

`/usr/local/lib/libaoclutils.so → /opt/aocl/gcc/lib_LP64/libaoclutils.so` is in place and
the warning is gone. Verified with more than an empty `main`: a real `dgesv` link is clean
*and* solves correctly (`[[2,1],[1,3]]x=(3,5)` → `x=(0.8, 1.4)`, exact), and `ldd` confirms
`libaoclutils.so` still loads from `/opt/aocl/...` via the absolute `DT_NEEDED` — so this
changed link time only, not runtime resolution. Keep the reasoning below; if a future
`blas-aocl-gcc` ships the symlink itself, this one becomes harmless.

Every C++ link against `-llapack` used to print:

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

## 6. ~~Remove the `postgresql` server~~ — DONE 2026-08-10, replaced by a container

Removed in favour of a container (version pinning per project, throw-away state). Full
write-up in `CLAUDE.md` under "Docker — socket-activated, and Postgres runs in a
container". Verified: server gone, `psql 18.4` works, insert/read-back through the
container round-trips.

**The command originally written here was unsafe.** `pacman -Rs postgresql` would also
have removed `postgresql-libs` — which is where `psql` lives — because it was installed
as a dependency and `Required By: postgresql` only. What was actually run:

```bash
sudo pacman -D --asexplicit postgresql-libs    # protects it from -Rs *and* from sysclean
sudo pacman -R postgresql                      # -R, not -Rs
```

The `--asexplicit` step matters beyond this one removal: without it `pacman -Qtdq` lists
`postgresql-libs` as an orphan, and `sysclean --all` runs `pacman -Rns --noconfirm` on
that list (item 9). Confirmed afterwards that `-Qtdq` is empty.

Also note the audit's stated reason was weak — "66 MiB, never initialised". 66 MiB is
noise next to `aocl-gcc` (686) or `agy` (172), and a disabled service costs nothing at
runtime. The real reason to remove it was architectural, not space.

`@postgres` was **kept**, not deleted: it is a mounted btrfs subvolume (so `rm -rf` gives
`EBUSY`, and removing it properly means an fstab edit whose failure mode is a boot
failure), and it now backs the container's `PGDATA` as a bind-mount. `chattr +C` was set
on it while empty, which had to happen before `initdb`.

---

## 7. `smartd` — decided 2026-08-10: **don't enable the daemon**

`smartmontools 7.5` is installed and `smartd.service` is disabled. The audit called this
"the only real configuration gap in 177 packages", which overstates it for **this**
hardware: one consumer NVMe (`nvme0n1`, SK Hynix 954 GB).

Why the daemon is the wrong tool here:

- NVMe has no ATA SMART attributes — the data lives in the **NVMe Health Information log
  (page 0x02)**, and the fields that predict anything (`percentage_used`,
  `available_spare` vs threshold, `media_and_data_integrity_errors`, `critical_warning`)
  move on a scale of **weeks to months**. 30-minute polling buys nothing.
- smartd is built for multi-disk ATA/SCSI servers: scheduled offline self-tests, and
  alerting by **mailing root**. There is no MTA here, so its alerts go nowhere and the
  only thing gained is journal lines.
- NVMe also tends to fail abruptly (controller death, read-only lockdown), which SMART
  does not foresee.

What to do instead: read it occasionally, `sudo smartctl -a /dev/nvme0n1`. Temperature is
readable without root via hwmon (40.9 °C when checked).

Optional follow-up if you want to be *told*: a weekly system timer that reads the health
log and notifies only when a threshold trips. That fits this repo's existing pattern for
root-owned tracked files (`pam/`, `system-sleep/` installed by `install-root.sh`) and
would be the system-level counterpart to `bash/service-failed-notify` — `notify-failure@`
is a **user** unit, so smartd could not use it. Strictly better than smartd for this
machine, but it is new code, not a one-liner.

---

## 8. ~~Make Docker actually usable~~ — DONE 2026-08-10: socket + group

`docker.socket` enabled; `docker.service` and `containerd.service` stay disabled and are
started on demand. User added to the `docker` group (gid 968), **knowingly accepting that
this is equivalent to passwordless root**. Rootless was evaluated and rejected — it
bypasses the `@docker` subvolume, needs two uninstalled packages, and would have required
subuid chowning for the Postgres bind-mount.

Verified: socket activation works (`docker.service` went inactive → active on first
command, containerd pulled in automatically), driver `overlayfs`, root `/var/lib/docker`
on the `@docker` subvolume, and a `postgres:18` container serving on `127.0.0.1:5432` with
a real insert/read-back through host `psql`.

Full reasoning and the container command live in `CLAUDE.md` under "Docker —
socket-activated, and Postgres runs in a container". Nothing was added to this repo:
`lazydocker` and Docker both run on defaults, and a config is only worth tracking once
customised.

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
