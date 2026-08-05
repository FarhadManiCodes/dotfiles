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
| 1 | **2** — rclone `client_id` | browser, 10 min | The only thing here that is actually *broken*. Everything else is tidying. |
| 2 | **1** — push `papis-ask` | nothing | 3 commits on one disk. |
| 3 | **1b** — give `SpackStream` a remote | `gh`, a visibility choice | 2 commits that exist nowhere else. |
| 4 | **5b** — press `Alt+n` in sioyek | nothing | Closes the one untested seam; also settles the page-label question. |
| 5 | **4** — AOCL symlink | sudo, 1 line | Removes a warning from every C++ link. |
| 6 | **6** — remove `postgresql` | sudo, 1 line | 66 MiB, never initialised. |
| 7 | **7** — enable `smartd` | sudo, 1 line | Only real config gap in 177 packages. |
| 8 | **8** — make Docker usable | sudo + a privilege decision | Needs you to choose group vs rootless. |
| 9 | **6b** — packaged `mutool` | sudo | Replaces a hand-dropped binary that gets no updates. |
| 10 | **3** — `sysclean --all` | sudo | Reclaims 2.7 GB; purely optional, `paccache.timer` already manages it. |
| 11 | **9** — `sysclean` `--noconfirm` | a decision | Latent, not active. Read before changing. |

Done: **1** (dotfiles pushed), **5** (tmux-resurrect verified).

---

## 1. ~~Push the dotfiles audit~~ — DONE, but `papis-ask` is still local

`dotfiles` is pushed (61 audit commits, `origin/master` in sync). **`~/projects/papis-ask`
still has 3 unpushed commits** — the whole note-ingestion feature:

```bash
cd ~/projects/papis-ask && git push        # branch: personal
```

---

## 1b. `projects/SpackStream` has no git remote at all — no sudo

2 commits, 15 files, 260 KB: the HPC container definitions (`cpp-linalg` with AOCL
prebuilt externals, mdspan, dev/release switch, image slimming). Last touched
2026-06-09. There is **nowhere to push it** — no remote is configured, so this work
exists on exactly one disk with no copy anywhere.

```bash
cd ~/projects/SpackStream
gh repo create SpackStream --private --source=. --remote=origin --push
```

Pick the visibility yourself. Nothing else in `~/projects` is exposed this way —
`paper-refinery`, `mathunicode`, `yts`, `cv-generator` and `Installs/sioyek` are all
clean and fully pushed.

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

## 5b. Press `Alt+n` in sioyek once — no sudo, 2 minutes

The whole sioyek -> papis -> `pask` note loop is built and tested, but never run
against real sioyek. Everything except the keypress itself was verified (script
end-to-end against a throwaway library, papis-ask unit tests, a live index of a
real note), so this is the one seam left.

Open any PDF **that lives in the papis library**, select a sentence, press `Alt+n`:

1. nvim should open in a half-width column with the cursor under a new block
2. check the heading page matches what sioyek shows. If it is off by one, swap
   `%{current_page_label}` and `%{page_number}` in `sioyek/prefs_user.config` —
   sioyek documents neither as 1-based, so both are passed and this is the only
   way to find out which is right
3. type a thought, save, then `pask index` and ask something only your note says.
   The source should read `@<ref> (note)`

If nothing happens, the likely cause is sioyek's argv splitting: this command
passes five `%{...}` placeholders where the existing ones pass at most two.
`journalctl --user -f` while pressing the key will show the script's stderr.

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
