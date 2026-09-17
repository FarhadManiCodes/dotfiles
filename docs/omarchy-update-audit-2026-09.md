# Omarchy update audit — September 2026

This audit compares Omarchy changes after the earlier closed comparison with this Arch Linux and Niri dotfiles setup. It records decisions rather than copying Omarchy implementation details blindly. Private secrets-management discussion is intentionally excluded from repository history.

The first reviewed Omarchy range ended at `31bd80da` (2026-09-11). A later remote refresh found 52 additional upstream commits through `9c5482c5` (2026-09-15); those later findings are included where already reviewed. The Omarchy checkout was fetched for comparison but not pulled while this document was started.

## Adopt

### Harden privileged configuration drift checks

Extend `bash/config-drift` for files installed by `install-root.sh`:

- Require regular files rather than symbolic links.
- Verify expected `root:root` ownership.
- Reject group-writable or world-writable targets.
- Check that relevant parent directories are root-controlled.
- Verify expected executable modes where applicable.
- Report inaccessible state as **not checked**, never as safe.
- Remain report-only; never repair privileged files automatically.

### Pin the command path in root scripts

After `install-root.sh` confirms it is running as root, set and export a fixed system-only `PATH` such as `/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin`. Keep user-local and repository directories out of privileged command lookup. Use absolute paths selectively for especially sensitive command identities.

This is defense in depth, not protection against a maliciously modified `install-root.sh`: the script itself remains in a user-writable checkout and must be reviewed before it is deliberately run through sudo.

### Harden the Vifm picker exchange

**Done 2026-09-17.** Replaced the predictable `/tmp/vifm-pick-*` protocol shared by `bash/vifm-pick` and `vifm/vifmrc`. The injection was demonstrated, not assumed — a file named `data"; touch PWNED; echo ".csv` executed `touch PWNED`, and the old construction was re-run as a positive control so the test was not blind. Opening and copying moved into the helper with argument lists; only `cd`/`goto` return to vifm, through `$XDG_RUNTIME_DIR/vifm-pick/` at mode 0700. A fixed directory name was chosen over a unique one: the parent is already 0700 and single-user, so uniqueness buys concurrency safety rather than security, at the cost of a much longer `vifmrc`. The original requirements were:

- Create a unique private exchange directory below `$XDG_RUNTIME_DIR`, mode `0700`.
- Pass that exact directory explicitly between Vifm and the helper.
- Validate returned actions against a fixed allowlist.
- Keep paths as data and correctly escape unavoidable Vifm command arguments.
- Prefer opening files and copying paths inside the helper with argument arrays so Vifm never builds shell commands from returned filenames.
- Remove the private directory after use.

This prevents predictable-path symlink attacks and crafted filenames crossing from path data into executable command syntax.

### Move remaining fixed runtime files out of shared `/tmp`

- **Done 2026-09-17.** Moved `/tmp/wobpipe` to `${XDG_RUNTIME_DIR}/wobpipe`, updating Niri startup and `bash/wob-control` together. `spawn-at-startup` does not re-run on config reload, so the live pipeline was migrated by hand the same way Niri will start it; verified by an OSD capture and by `volume-up`/`volume-down` moving the sink ±5% without blocking on the FIFO.
- **Done 2026-09-17.** `playaudio` now creates its fzf/mpv playlist with `mktemp` below `$XDG_RUNTIME_DIR` rather than truncating `/tmp/fzf_audio_queue.txt`, and removes it once mpv — the last reader, which outlives the function — exits. Verified with stubbed `find`/`fzf`/`mpv`: the queue is mode 0600, still present while mpv reads it, and gone afterwards on both the queued and empty-selection paths.

The later Omarchy screen-recording fix confirms this rule but adds no separate recording task: `toggle-record.sh` writes audio directly below `~/Audio/Recordings` and stores no trusted control pathname in `/tmp`. Other reviewed temporary files outside the Neovim submodule already use `mktemp`; the Neovim submodule remains outside this finding.

### Validate `tmux-cpp-tools clean-all` targets

Before recursive deletion, resolve and prove that `PROJECT_ROOT` is a valid project directory and `BUILD_DIR` is exactly its intended `build` child. Refuse deletion if that invariant cannot be established. Keep removal of `compile_commands.json` constrained to the same validated project root.

### Protect package transactions from user-session teardown

Design and test a local equivalent of Omarchy's PID-1 system-scope protection for `sysup`. Omarchy's direct-Pacman wrapper cannot be copied unchanged because Paru must remain unprivileged while building AUR packages.

The local implementation must:

- Launch Paru as the normal user inside a PID-1-managed system scope that survives user-manager re-execution.
- Preserve its interactive terminal, working directory, required trusted environment, and user identity.
- Confirm that Paru's elevated Pacman descendant stays in the protective system scope.
- Fail visibly rather than silently continue without protection if the scope cannot be established.
- Include a diagnostic or test proving both Paru and Pacman are outside the user manager's cgroup.
- Retain the existing sleep/idle inhibitor, which protects against a different interruption mechanism.

### Preserve the existing rootless container boundary

The current setup already satisfies Omarchy's Docker-group hardening. Continue using rootless Podman and its user socket; never enable the system Podman socket, use `sudo podman`, or join a group controlling a root-owned container socket. `/var/lib/docker` is only the legacy name of the user-owned rootless graphroot.

### Preserve the single-source firewall flow

Keep `etc/nftables.conf` as the tracked source, copy it through `install-root.sh` to root-owned `/etc/nftables.conf`, and let `nftables.service` load only the installed copy. Cover it with the privileged drift checks above.

### Prefer bounded privileged services

For future graphical or background operations requiring privilege, first look for an existing bounded system D-Bus service such as `systemd-timedated`, `systemd-hostnamed`, or `systemd-logind`. Prefer a typed method and narrowly scoped Polkit action over a passwordless sudoers grant for a general-purpose command. No timezone authorization is needed now because the dotfiles only read the timezone.

### Keep the existing agent set small

Claude, Codex, and AGY are installed. A future general launcher may default to Claude and allow explicit Codex or AGY selection while preserving each tool's normal approval behavior. Do not add unrestricted approval-bypass modes. The Claude/tmux workspace layout remains a separate design task.

## Benchmark or decide before adoption

### BBR with `fq` pacing

Decision pending. The current kernel supplies `tcp_bbr`, while the live system uses Cubic and does not expose `net.core.default_qdisc` until the relevant queue-discipline support is loaded. Do not copy two sysctl lines without verification.

Before deciding:

1. Measure idle latency, loaded upload/download latency, and throughput with Cubic.
2. Temporarily load the required BBR and `fq` modules, apply the settings, and repeat the measurements.
3. Retain the change only for a material improvement.
4. If adopted, ensure module loading is persistent and make drift checks report when either sysctl fails to apply.

### Kyber I/O scheduling

Decision pending. The machine has one SK hynix NVMe device, `nvme0n1`, currently using the kernel's `none` scheduler with `mq-deadline`, `kyber`, and `bfq` available. Kyber may improve interactive read latency while builds, package updates, copies, or data jobs saturate the device, but it may reduce peak throughput relevant to scientific and data workloads.

Before deciding:

1. Measure a representative heavy-write workload with `none`, including throughput, interactive read tail latency, CPU cost, and desktop responsiveness.
2. Temporarily switch only `nvme0n1` to `kyber` and repeat the same measurement.
3. Retain the change only when responsiveness improves without an unacceptable workload penalty.
4. If adopted, use a narrowly targeted udev rule, install it through `install-root.sh`, and cover it with the privileged drift checks.

### SSH server

Decision pending. Preserve the current safe state: no configured `sshd` and no SSH firewall opening. If remote SSH is later wanted, verify at least one usable public key before enabling the service or firewall, disable password authentication, prohibit root login, retain local recovery, and verify the effective daemon configuration.

### Claude and ChatGPT/Codex desktop applications

Claude Desktop is not officially packaged for Arch. Omarchy's public recipe repackages the official vendor Debian package, pins its checksum, and supplies Arch and Wayland integration. The application remains proprietary even though the packaging recipe is reviewable. If Claude Desktop is wanted later, adapt that recipe locally rather than enabling the complete Omarchy package repository solely for this application.

The Codex CLI, Codex Desktop, and ChatGPT Desktop are distinct applications. Omarchy's public `openai-codex-desktop` recipe repackages the official Linux desktop application, pins checksums, and adds desktop and Wayland integration. The application remains proprietary while the packaging recipe is public and reviewable. If adopted, reconsider Omarchy's forced native-Wayland options for the local Niri configuration and display scale rather than copying them unchanged.

### 1Password display scaling

Revisit only if 1Password is installed and an Electron/Wayland scaling problem is observed. Do not configure a workaround pre-emptively.

### Temporary sudo convenience

There is no current `NOPASSWD` rule to change. If temporary cached or passwordless convenience is introduced later, require a clear lifetime, verified expiry, and fail-closed behavior.

### Matching kernel headers for DKMS

Conditionally required, with no package change now. The machine has the stock `linux` and `linux-lts` kernels, no matching header packages, and no installed DKMS modules. Headers are therefore not currently needed for normal kernel operation.

If a DKMS package is introduced, install the headers matching every kernel for which the module must work before installing or building the module—currently `linux-headers` and `linux-lts-headers`. Stop when header installation fails, verify each `/usr/lib/modules/<release>/build` tree matches its kernel, and require `dkms status` to report successful builds. Treat a DKMS package without matching headers as incomplete installation.

## Already safe or already handled

- The fixed global `PATH` has no automatic `./bin`, `$PWD/bin`, or Mise project-bin injection. Keep invoking trusted project tools explicitly, such as `./bin/tool`.
- `sysup` already treats a failed `paru -Syu` as failure and does not print an independent claim that package keys are correct; no Omarchy-style keyring helper is needed.
- `zsh/update-plugins.sh` accepts no arbitrary repository URL and uses a fixed HTTPS list. Keep the interface fixed. Zsh plugins are intentionally executable code; commit pinning was considered separately and declined.
- Fixed desktop entries need no generic web-app name/path validation. If a creator is added later, separate its display name from a strictly validated internal identifier.
- There is no privileged sudo/faillock reset helper interpolating environment data into a shell command.

## Declined or not applicable

- Quickshell plugin authorization: no Quickshell or comparable in-process third-party desktop plugin host.
- Perplexity Desktop, Basecamp CLI: not used.
- Hermes and OpenClaw: persistent services, credentials, memory, tools, and plugin/runtime surfaces overlap existing agents without a concrete need.
- T3 Code: overlaps the separately planned tmux agent workflow.
- Cursor CLI: revisit only for a specific need for Grok coding-agent access.
- Muse Code: background-agent and worktree features overlap existing tools and add another provider.
- Ori: another provider account, credential, billing relationship, and data processor for OpenRouter model experimentation; no current need.
- Claude browser integration: unsupported by the current Firefox workflow and expands the agent's access to browser content and actions. Do not install its Chromium extension system-wide or force `--chrome`. If browser automation becomes a concrete need, evaluate it separately with a dedicated Chromium profile, minimal logged-in accounts, and explicit activation.
- Video wallpapers and Omarchy's fullscreen-desktop toggle: Quickshell/Hyprland-specific and not useful enough to reproduce under Niri.
- Broadcom DKMS, hybrid-GPU/`supergfxctl`, Elgato Wave, KEF speakers, and the keyboard-layout widget: hardware or shell assumptions do not match this machine.
- `libfprint-git`: the reader works with stable `libfprint` and `fprintd`; switch only for a demonstrated support gap.
- `plocate`: previously considered and declined.
- Kitty hardening: Foot is the terminal.
- FIDO2 PAM enrollment: not used; SSH hardware-key use would be a separate design.
- Windows VM hardening: no Windows VM or root container daemon.
- Omarchy's screen-recording state change: no analogous local recording state; the general `/tmp` findings are already adopted above.

## Completed upstream range

The potentially transferable items in the later Omarchy range through `9c5482c5` have been classified. Factory reset, Windows RDP password handling, Quickshell/QConsole, Plymouth, Omarchy kernel selection, and hardware-specific fixes remain out of scope unless the local setup changes.
