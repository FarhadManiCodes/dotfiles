# Tmux

- **Config**: `tmux/tmux.conf` — prefix `Ctrl-a`
- **Layouts**: `tmux/layouts/cpp_layout.sh` — the only one; `Prefix W` runs it directly
- **Identity segment**: `bash/tmux-identity`, run from `tmux.conf` **before tpm** (when
  tmux-power reads `@tmux_power_*`). tmux-power's stock `left_a` is ` #{USER}@#h` —
  "farhad@arch-thinkpad", a permanent slot spent on two facts never in doubt. The helper
  blanks it when local as the usual user, and tmux-power then omits the block entirely
  rather than drawing an empty coloured stub. Over ssh it shows the hostname, for another
  user the username, for both `user@host`.

  It's computed **once at config load**, and has to be: `#{SSH_CONNECTION}` always expands
  empty, because tmux resolves only its own format variables and not arbitrary server
  environment, and `#{==:X,}` treats an empty right operand as always-equal, so the
  natural emptiness test is true whatever the variable holds. `SSH_CONNECTION` comes from
  the environment that started the *server*, so a tmux started locally and attached later
  over ssh keeps the segment hidden.
