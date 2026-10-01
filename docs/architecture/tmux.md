# Tmux

- **Config**: `tmux/tmux.conf` — prefix `Ctrl-a`
- **Layouts**: `tmux/layouts/cpp_layout.sh` — the only one; `Prefix W` runs it directly
- **Identity segment**: an `%if` block in `tmux.conf`, **before tpm** (when tmux-power
  reads `@tmux_power_*`). tmux-power's stock `left_a` is ` #{USER}@#h` —
  "farhad@arch-thinkpad", a permanent slot spent on two facts never in doubt. The block
  leaves it empty when local as the usual user, and tmux-power then omits the segment
  entirely rather than drawing an empty coloured stub. Over ssh it shows the hostname, for
  another user the username, for both `user@host`.

  It's decided **once at config load**, and has to be: tmux-power drops a segment only if
  its text is empty when it loads, so a format that merely renders empty would leave a stub.
  `%if` reads the environment that started the *server*, so a tmux started locally and
  attached later over ssh keeps the segment hidden. (Until 2026-10-01 this was
  `bash/tmux-identity`, whose header claimed formats could not see `SSH_CONNECTION` and
  that `#{==:X,}` was always true; tmux 3.7c shows neither holds.)
