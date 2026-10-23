# Herdr through Cargo

The tmux-to-Herdr migration is planned in `docs/herdr-migration.md` (decisions) and
`docs/herdr-implementation.md` (milestones and acceptance criteria).

`bash/herdr-cargo` installs the latest stable upstream Herdr release into
`${CARGO_INSTALL_ROOT:-${CARGO_HOME:-$HOME/.cargo}}/bin/herdr`. `--root DIRECTORY`
overrides that installation root. It uses the existing Cargo source cache and
installed Rust/C compiler; it does not install Rust toolchains, clippy, rustfmt,
Ghostty's terminal application, services, shell integrations or completions.

```sh
bash bash/herdr-cargo --check    # default: metadata inspection only
bash bash/herdr-cargo --install  # install/update or adopt an official Cargo Git build
bash bash/herdr-cargo --update   # update only; skip when the executable is absent
```

The normal helper mapping in `install.sh` links it to `~/.local/bin/herdr-cargo`.
The installer invokes `--install` as its last step (the build needs the network and takes
minutes), and reports a failure, or an interrupt (exit 130 or 143), in its final summary. An interrupt ends
`install.sh` with that status even if user units also failed to enable (those are still listed). `sysup` invokes `--update` after
`cargo install-update --all`, reports a failed Herdr update with its reason, continues, and
finishes non-zero. Ctrl+C there skips the update once, see [Ctrl-C in sysup](zsh.md#ctrl-c-in-sysup). If `HERDR_CARGO_REASON_FILE` names a file, the helper also writes its failure
message there so `sysup` can repeat it. That general
Cargo command skips Git installs; do not add `--git` to update Herdr, because
the stable selection, SDK provisioning and build flags belong to this helper.
Reload `~/.zshrc` in existing shells after updating the `sysup` function.

## Release and compiler selection

The helper reads GitHub's latest stable release, rejects draft/preview tags,
and resolves the Git tag, including annotated tags, to a full commit. The Cargo
package version must match the tag. Compilation uses that commit with
`--locked --bin herdr --target x86_64-unknown-linux-gnu`.

Zig follows the selected release's `.github/workflows/release.yml` setup-zig
pin, cross-checked against the vendored engine's `.minimum_zig_version`. The
helper downloads that exact stable compiler from Zig's official index, verifies
its SHA-256 checksum and checks the extracted compiler's version. It never
substitutes the newest Zig. For Herdr v0.9.5, this selects Zig 0.16.0, even though
newer stable/development Zig versions exist.

CI/workspace metadata changes that the conservative parser cannot interpret
stop the update with an explanation. Review the release build files rather
than guessing a compiler version or executing the CI script.

Sources: [Herdr release workflow](https://github.com/herdrdev/herdr/blob/v0.9.5/.github/workflows/release.yml),
[engine requirement](https://github.com/herdrdev/herdr/blob/v0.9.5/vendor/libghostty-vt/build.zig.zon),
[Cargo build script](https://github.com/herdrdev/herdr/blob/v0.9.5/crates/ghostty-vt/build.rs),
[official Zig download index](https://ziglang.org/download/index.json).

## Build and installation

The recipe is specific to this Zen 4 laptop; mutating modes reject a host that
Rust does not identify as `znver4`. Build settings are scoped to the helper's
process, never exported into `.zshenv` or a global Cargo configuration:

| Setting | Value |
|---|---|
| Rust CPU | `-C target-cpu=znver4` |
| Rust optimization / LTO / codegen units | `3` / `fat` / `1` |
| Strip / panic strategy | `symbols` / `unwind` |
| Zig engine | `ReleaseFast`, SIMD enabled |
| Cargo parallel jobs | `8` (build resources only) |

The panic strategy preserves the engine wrapper's `catch_unwind` handling.
Herdr has no optional Cargo features in v0.9.5; `--no-default-features` does
not reduce this build. The engine is mandatory and statically linked into
Herdr. Native libraries still follow the normal GNU/Linux target rather than
an extra musl toolchain. See [Cargo profile settings](https://doc.rust-lang.org/cargo/reference/profiles.html).

Mutating operations use a unique directory under
`${XDG_CACHE_HOME:-$HOME/.cache}/herdr-cargo`, including Zig's caches, Cargo's
target/build directory and subprocess temporary files. This avoids large
build files in this machine's RAM-backed `/tmp`. Exit, ordinary failure and
Ctrl+C (exit 130; the Git lookup runs under `timeout --foreground` so the key reaches it at once)
clean that operation's directory; Cargo's shared downloads and Git
checkout remain reusable. A kill the shell cannot catch (SIGKILL, power loss) leaves the
directory behind, so each mutating run removes `build.*` directories older than a day once
it holds the lock. `--check` creates only a temporary metadata directory.

Cargo first installs into a temporary staging root. Its executable must report
the expected release before a second Cargo installation promotes the same
candidate into the real root, reusing its build artifacts. A failed compilation,
checksum or staged version check leaves the installed executable untouched.
An error during final filesystem/metadata installation is reported as a failure;
the helper does not promise rollback of an interrupted Cargo promotion.

The helper refuses unrecognized ownership, executable symlinks and downgrades.
An operation lock prevents concurrent helper runs; an executable/source recheck
before promotion detects another installation changing during the build.

`<installation-root>/.herdr-cargo.json` (normally under `~/.cargo`) records
the tag, full commit, compiler versions, recipe,
executable SHA-256 and size. Matching source, recipe and binary need no build
or compiler download. An ordinary/unrecorded official Cargo build is rebuilt
once to apply the recipe. A Rust package update alone does not force a rebuild.

## Updates and removal

Use `herdr-cargo --check` to inspect and `herdr-cargo --update` to update.
Running servers retain their existing executable and panes. The helper does
not restart or stop sessions; do that deliberately after reviewing Herdr's
[session/update guidance](https://herdr.dev/docs/install/).

Use `cargo uninstall herdr` for the default root, or
`cargo uninstall --root DIRECTORY herdr` for a custom root. Herdr configuration
and session data are separate. The helper's small record/lock can remain;
update-only mode skips an absent executable, so `sysup` does not reinstall it.
Running the full `install.sh` does request installation again.

## Local LTO evidence, 2026-10-21

Compared Herdr v0.9.5 commit `2ecf19a92fc3a7fff75b6ce3655ef04f4625ec01`, Rust
1.99.1 and Zig 0.16.0 on Ryzen 7 PRO 7840U. Only Rust LTO differed; the native
engine archive hashes matched. Fat completed a fixed 99 MiB colored UTF-8
output batch sooner in all eight alternating pairs (median paired completion
time reduction 6.64%, CPU/work reduction 6.99%) and was 2.17% smaller on disk.

| Combined client/server measurement | Thin | Fat |
|---|---:|---:|
| Executable | 21.45 MiB | 20.99 MiB |
| Idle PSS | 23.20 MiB | 23.42 MiB |
| Visible-output PSS | 32.93 MiB | 32.69 MiB |
| 15 background writers, PSS | 141.92 MiB | 141.51 MiB |

Memory is the median of per-run mean PSS, excluding shells, producers and the
terminal drain. Twelve sustained 60-second samples, 16 batch measurements and
six idle samples passed workload checks. Sustained CPU results varied and did
not establish a consistent winner; fat is a batch-throughput/size choice, not
a claim of universal speed or RAM improvement. The outer terminal was a
continuously drained 120x40 PTY, with fresh isolated state and warm file caches;
Foot/compositor painting, images and actual agents were not benchmarked.
Power policy was left at powersave/balance_power, boost disabled. Retest when
new Herdr/compiler versions or hardware changes justify it.
