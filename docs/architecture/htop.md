# htop

`htop/htoprc` is the tracked template. `install.sh` copies it to
`~/.config/htop/htoprc` only when no live config exists; later installs leave
the live file alone.

- Main keeps the original columns except VIRT and adds START before TIME+.
- I/O shows S after USER and the total, read, and write disk rates. It sorts by
  total disk rate.
- Tab and Shift-Tab switch between the two screens.

htop can rewrite the live file when saving interactive choices such as sort
order or Setup (F2). Deliberate layout changes can be copied from the live
file back to the tracked template after review. `htop_history` is session
state and is not tracked.
