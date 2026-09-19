# Neovim (primary editor)

Submodule at `nvim/` → [FarhadManiCodes/nvim-config](https://github.com/FarhadManiCodes/nvim-config).
Symlinked: `~/.config/nvim` → `dotfiles/nvim`.

**Two separate things to update, and confusing them is how the plugins went stale.** The
*config* is the submodule (`cd nvim && git pull`, then commit the pointer). The *plugins*
are lazy.nvim's, 37 under `~/.local/share/nvim/lazy/`, untouched by a submodule pull —
`sysup` runs `nvim --headless "+Lazy! sync" +qa` for that, added 2026-09-04. Before that
they sat frozen from 25 July with lazy.nvim itself nine months behind, silently.

lazy is **lockfile-based**, unlike the other three plugin ecosystems:

- A sync rewrites `nvim/lazy-lock.json` in the **submodule**, so an update leaves a second
  git repo dirty. `sysup` compares its sha256 (not mtime — lazy rewrites the file
  unconditionally on every sync) to report whether anything actually changed.
- That lockfile is also the rollback:
  ```bash
  git -C ~/dotfiles/nvim checkout lazy-lock.json
  nvim --headless "+Lazy! restore" +qa
  ```

**`sysup` runs `:checkhealth` right after the sync** (2026-09-05) — a sync is exactly when
nvim breaks silently (a dropped dependency, a deprecated API, a treesitter ABI mismatch);
`Lazy! sync` still reports success while the editor quietly does less. Costs ~2.9s
headless, so it runs every time.

**Errors are always listed; warnings only when the set changes** — most warnings are
permanent and not actionable (e.g. `jupytext.nvim` reporting no CLI, which is deliberate,
see `revisit.md`), and printing them every run turns a warning into wallpaper. But
permanent isn't the same as benign — `jupytext.nvim`'s deprecated `vim.validate{<table>}`
warning is fixable and breaks at Nvim 1.0, not merely cosmetic. Report at
`~/.local/state/sysup/nvim-health.txt`, warning set beside it.

`config-drift` doesn't ask whether these plugins are behind upstream, unlike the other
three ecosystems — lazy pins them, so "behind" is what pinning means and the check would
flag all 37 forever. It checks the lockfile's **age** instead — the only offline signal
distinguishing "not synced" from "synced, nothing changed".
