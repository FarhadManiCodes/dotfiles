# Symlink model

Every tracked config is a symlink pointing into this repo. `install.sh` creates all
symlinks. To check whether dotfiles are in sync, use `ls -la` to confirm symlinks — not
file contents.

**`git checkout <branch>` changes your live configuration.** Every tracked config is a
symlink *into this repo*, so switching to a branch that lacks a file makes it vanish from
the running system. This bit on 2026-09-03: `~/.ssh/config` became a dangling symlink and
`environment.d/defaults.conf` silently reverted, so ssh stopped using the agent. Treat a
checkout as a config change — after switching branches, expect the live system to match
that branch, not the last one.

**Not tracked (intentionally):**
- `~/.config/git/config.local` — name + email
- `~/.config/gh/hosts.yml` — auth tokens
- the `pg_password` podman secret — `/var/lib/docker/secrets` (podman's graphroot, not
  `~/.local/share/containers`, which doesn't exist here)
- `~/.config/zsh/plugins/` / `completions/` — cloned/generated, not authored
- `gtk-3.0/bookmarks` — local state
- `~/.config/rclone/rclone.conf` — OAuth tokens

**Checked and deliberately left untracked** (2026-09-04 sweep, so these aren't
re-examined every audit):
- `~/.config/ripgrep-all/` — `config.jsonc` is rga's shipped default; tracking it would
  pin something upstream owns.
- `~/.config/paper-refinery/` — sits beside `secrets/{google,hf,zai}.env`; a config whose
  siblings are API keys doesn't belong in a public repo (one careless `git add -A` leaks
  it). Those keys have no backup — losing them means re-issuing all three.
- `~/.config/Z-Library/` — 64 MB of Electron state, not configuration.

Rerun the sweep after installing anything new — the user-side counterpart of the
`pacman -Ql` diff that produced `etc/`:

```bash
cd ~/.config && for e in */; do n="${e%/}"
  [ -L "$n" ] || [ "$(find "$n" -maxdepth 2 -lname '*dotfiles*' | wc -l)" -gt 0 ] || echo "$n"
done
```
