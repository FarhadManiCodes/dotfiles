# TODO — actions that need me, not the config

Left over from the 2026-07/08 config audit. Each item needed a browser, a decision, or
root — something no script in this repo could do.

**All items are closed as of 2026-08-10.** The entries are kept rather than deleted,
because several of them record *why* the obvious action was wrong; the reasoning is the
part worth not rediscovering. New items go at the bottom.

For issues investigated and **accepted** (nothing to do), see `revisit.md`.
For what was changed and why, across all repos, see `AUDIT-2026-08.md`.

## Status

| Item | Outcome |
|---|---|
| **1** | dotfiles + `papis-ask` pushed |
| **1b** | `SpackStream` on GitHub, private (2026-08-09) |
| **2** | rclone on a personal Drive `client_id` (2026-08-09) |
| **3** | `sysclean --all` run — 1.4 GB reclaimed, not the estimated 2.7 (2026-08-10) |
| **4** | AOCL `libaoclutils` symlink; linker warning gone (2026-08-10) — symlink **retired 2026-08-14**, no longer needed |
| **5** | tmux-resurrect verified working |
| **5b** | `Alt+n` in real sioyek — **found two placeholder bugs** (2026-08-10) |
| **6** | `postgresql` server → container; `psql` protected (2026-08-10) |
| **6b** | decided: **keep** the hand-built `mutool` |
| **7** | decided: **no** `smartd` — wrong tool for a single NVMe |
| **8** | Docker socket + group (2026-08-10) — **superseded 2026-09-02 by rootless podman** |
| **9** | `sysclean` now prompts before removing packages (2026-08-10) |

**Four items closed by rejecting the audit's own recommendation** after checking it: **6**
(the stated reason — 66 MiB — was noise), **7** (smartd is built for multi-disk ATA, not
one NVMe), **6b** (the swap costs ~23 MiB *more* and doesn't fix the real exposure), and
**3** (the 2.7 GB estimate was the whole cache, not the recoverable part). Two items' own
commands were **unsafe as written**: **6**'s `pacman -Rs` would have deleted `psql`, and
**9** described an `--all` hazard that actually ran in every mode.

The **nvim submodule audit** was deferred here and has since been done (2026-08-11/12) —
see the nvim section of `AUDIT-2026-08.md` for the findings, and `revisit.md` for the
additions that were investigated and declined. Still optional and untouched: a weekly
NVMe-health timer as the sane alternative to `smartd` (item 7).

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

## 3. ~~Reclaim ~2.7 GB~~ — DONE 2026-08-10, reclaimed ~1.4 GB

`sysclean --all` run after the item 9 fixes. Pacman cache **2.7 G → 1.3 G**, uv cache
cleared, ccache cleared (`0.0 / 5.0`), paru 1.3 M. Filesystem now 25 G used, 926 G free.

**The "~2.7 GB" estimate was too high** — that was the whole cache, but `paccache -rk1`
keeps one version of every *installed* package, and those 272 files are the remaining
1.3 G. The recoverable part was the older versions, not the cache.

Nothing was lost: `postgresql-libs`, `aocl-gcc`, `blas-aocl-gcc`, `qpdf`,
`ripgrep-all`, `pacman-contrib`, `docker` and `smartmontools` all still installed,
`psql 18.4` still runs, and `pacman -Qtdq` is empty so the orphan step had nothing to
prompt about.

**The item 9 journal change proved itself on this very run.** Journal held at 24 M with
the oldest entry 2026-07-19, and the 2026-07-24 rclone DNS error — the evidence used
earlier that day to disprove the "403 quota exceeded" claim — is **still there**. Under the
previous `--vacuum-time=2weeks` this run would have deleted it, since it was 17 days old.

Still **not** neglect: `paccache.timer` is enabled and prunes automatically, and the
steady state is its default `-k3` (three versions kept). To keep it smaller without
running this by hand:

```bash
sudo systemctl edit paccache.timer   # or override PACCACHE_ARGS in the service
```

---

## 4. ~~AOCL: one symlink to silence the linker~~ — DONE 2026-08-10, **retired 2026-08-14**

The symlink is **gone**, and nothing replaced it — the problem it solved no longer exists.
Three things had to be true, and AOCL 5.3.0 plus the adapter removal falsified all of them:

- the warning came from `/usr/lib/liblapack.so`, a `blas-aocl-gcc` symlink. That package was
  removed on 2026-08-14 (see the AOCL section of `CLAUDE.md`), so there is no such file.
- 5.3.0 moved the library trees into `MT/`, so the symlink's target
  (`/opt/aocl/gcc/lib_LP64/libaoclutils.so`) had been **dangling since 2026-08-11** —
  provably contributing nothing, since a dangling symlink cannot satisfy a link.
- 5.3.0's `libflame.so` records *absolute* `DT_NEEDED` paths for both `libaoclutils.so` and
  `libblis-mt.so`, so `ld` resolves the transitive dependency with no help at all.

Verified: a clean CMake build of `~/learning/playground/aocl-check` (real `dgemm`/`dtrsm`/
`dgesv`, all exact) emits **no linker warnings**. Removed with
`sudo rm /usr/local/lib/libaoclutils.so`; `/usr/local/lib` is now empty.

The reasoning below is kept because one part of it still governs: **never** put AOCL's lib
dir on the runtime loader path. That is now recorded in `CLAUDE.md`, along with the sharper
version of it found on 2026-08-14 — `DT_RUNPATH` is searched *before* `ld.so.cache`, so even
a per-binary AOCL rpath hijacks FFTW unless `/usr/lib` is listed first.

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

## 6b. `mutool` — decided 2026-08-10: **keep it**, do not swap for `mupdf-tools`

Every premise in the original version of this item was wrong, so it is written out here
rather than deleted.

- **It is not a hand-dropped download.** `~/.local/bin/mutool` is byte-identical (sha256
  `b5e0c5ac…`) to `~/Installs/sioyek/mupdf/build/release/mutool` — a by-product of the
  sioyek build, at `-march=znver4`. Provenance is a source tree you maintain.
- **Swapping it costs ~23 MiB, it does not save any.** This item claimed `mupdf-tools`
  "links the shared mupdf libraries instead of bundling them", implying smaller. Actual:
  `mupdf-tools` 737 KiB **+ `libmupdf` 55.9 MiB + `tesseract` 4.8 MiB + `leptonica`
  3.6 MiB + `gumbo-parser` 381 KiB**, none installed — an OCR stack pulled in to replace
  42 MiB.
- **It would not fix the actual exposure.** The only untrusted-input path is the vifm PDF
  preview (`vifm/vifmrc:149`, `mutool draw -F txt`). But sioyek **statically bundles the
  same mupdf 1.26.11** (submodule pinned at `d189cc131`, 0 shared `libmupdf` in `ldd`, and
  0 `mutool` strings — so sioyek does not call it, they merely share a build). Sioyek is
  what actually opens downloaded papers. Patching the CLI to 1.28.0 while the reader stays
  at 1.26.11 buys a false sense of security.

The real hygiene action, if any: rebuild sioyek — that refreshes `mutool` for free at
znver4. Note it would not reach mupdf 1.28.0, because the submodule pin is upstream
sioyek's choice. The checkout is 15 commits behind `upstream/development` (34 behind
`upstream/main`), last built 2026-07-20.

Also unaccounted for in `~/.local/bin`: **`agy`, 172 MiB** (an AI CLI agent, v1.1.0,
placed 2026-07-08) and **`~/.local/share/sioyek/sioyek`, 46 MiB**. Both hand-installed
and owned by no package. Not defects — just know they exist and get no updates.

---

## 6. ~~Remove the `postgresql` server~~ — DONE 2026-08-10, replaced by a container

Removed in favour of a container (version pinning per project, throw-away state). Full
write-up in `CLAUDE.md` under "Containers — rootless podman, and Postgres as a Quadlet
unit". Verified: server gone, `psql 18.4` works, insert/read-back through the
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

Full reasoning lived in `CLAUDE.md` under "Docker — socket-activated, and Postgres runs
in a container"; that section is now "Containers — rootless podman, and Postgres as a
Quadlet unit". Nothing was added to this repo:
`lazydocker` and Docker both run on defaults, and a config is only worth tracking once
customised.

### Superseded 2026-09-02 — migrated to rootless podman

The group membership accepted above turned out to be the wrong trade. It was *demonstrated*
rather than argued: `docker run -v /:/host alpine` read `/etc/shadow` from a normal shell
with no password. That meant any code already running as the user — an AUR `build()` during
`sysup`, a PyPI package behind a `uv tool`, an AI CLI agent — could take root silently.

Docker is gone: packages, daemon, socket, `docker` group (`groupdel`), `/etc/docker`, and
the contents of `/var/lib/docker`. Postgres now runs as a Quadlet unit under rootless
podman with every process owned by `farhad`.

The rootless rejection recorded above does not transfer to podman: it was about chowning the
bind-mount to subuid `100998`, which `UserNS=keep-id:uid=999,gid=999` avoids entirely — the
data directory is simply owned by `farhad`.

Two things this also fixed, both found while migrating:

- **Socket activation was silently breaking "always on".** `docker.service` was disabled by
  design, so `--restart unless-stopped` never took effect at boot. Measured: **139 minutes**
  from boot to daemon start on 2026-09-01, all of it with the database down, ended only by an
  unrelated `docker ps`. The Quadlet unit is `WantedBy=graphical-session.target` and now comes
  up with the session — 108 seconds after boot, and that is just the login.
- **The container definition was documentation, not infrastructure.** It existed only as a
  fenced code block in `CLAUDE.md`. It is now `containers/pg.container`, tracked and installed
  by `install.sh`, with `OnFailure=notify-failure@%n.service` like every other service here.

Contrary to the note above, this *is* tracked now — `containers/` holds three files, all
user-scoped, all installed with no sudo.

---

## 9. ~~`sysclean` removed orphans unattended~~ — DONE 2026-08-10

Three changes to `zsh/functions/sysclean.zsh`, all deliberately confined to the offending
lines:

1. **`pacman -Rns … --noconfirm` → `pacman -Rs …`.** Dropping `--noconfirm` lets pacman
   print the list and ask; the old code echoed the names and then removed them anyway, so
   you saw it happen but could not stop it. Dropping `-n` (`--nosave`) means a mistaken
   removal leaves `.pacsave` instead of deleting the configuration too.
2. **`journalctl --vacuum-time` 2 weeks → 2 months.** Short retention reclaimed nothing
   and destroyed evidence: the journal sits at ~24 MB and journald already caps itself
   (`SystemMaxUse` defaults to 10% of the filesystem, 4 G cap, no overrides in
   `journald.conf`).
3. **The unreachable `pacman -Sc/-Scc --noconfirm` fallback** kept as a genuine fallback
   for a machine without `pacman-contrib`, but with `--noconfirm` removed.

**This item's own framing was wrong in one respect:** the orphan block is **not** gated
behind `--all` — it ran in *both* modes, while the function's docstring calls the plain
mode "Safe routine cleanup". That is now noted in the docstring.

And the risk turned out not to be latent. On **2026-08-10**, removing the `postgresql`
server made `postgresql-libs` — which owns `psql` — an orphan candidate. It was only saved
by marking it `--asexplicit` first. `pacman -Qtdq` lists packages installed *as
dependencies* and no longer required, which is **not** the same as unwanted; that reasoning
now lives in a comment at the call site.

Verified: `zsh -n` parses, the function still defines, no `--noconfirm` remains, and
`2months` is a valid systemd time span (`systemd-analyze timespan`, with a deliberately
bogus control to prove the check could fail).
