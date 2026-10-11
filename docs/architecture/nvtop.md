# nvtop

`nvtop/interface.ini` is a template generated with nvtop 3.3.2 using Setup
(F2) and Save Config (F12). `install.sh` copies it to
`~/.config/nvtop/interface.ini` only when no live config exists. Existing
files and symlinks are left alone.

The process list shows PID, USER, TYPE, GPU, GPU MEM, CPU, HOST MEM, and
Command, in that order. Device ID (`DEV`) is hidden. GPU memory remains the
descending sort field.
The refresh interval is 2 seconds.

nvtop 3.3.2 computes the graph height from the terminal layout; its Setup
window does not offer a graph height control. The `-p` option hides the plot
entirely.

nvtop saves interactive changes to its config with F12. The private live copy
keeps those changes out of the tracked template. To change the template, use
F2 and F12 in nvtop, then review and copy the saved file into the repo.
