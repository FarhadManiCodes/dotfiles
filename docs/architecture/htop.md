# htop

`install.sh` links `htop/htoprc` to `~/.config/htop/htoprc`.

- Main keeps the original columns except VIRT and adds START before TIME+.
- I/O shows S after USER and the total, read, and write disk rates. It sorts by
  total disk rate.
- Tab and Shift-Tab switch between the two screens.

The live config is the tracked file. htop can rewrite it after changes in Setup
(F2), including settings saved by an instance opened before a manual edit. Quit
htop before editing the file and review any later repo diff. `htop_history` is
session state and is not tracked.
