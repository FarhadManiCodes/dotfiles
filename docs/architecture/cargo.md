# Cargo defaults

`install.sh` links `cargo/config.toml` to `${CARGO_HOME:-$HOME/.cargo}/config.toml`.
The directory also holds private Cargo state; only this config file is tracked.
`config-drift` checks the link against the same destination.

Linux x86-64 builds use `-C target-cpu=native`. On this Ryzen 7 PRO 7840U,
Rust identifies the native CPU as `znver4`. This applies to ordinary Cargo projects,
`cargo install` and the `cargo install-update --all` builds run by `sysup`.
It affects future builds; existing installed binaries are not rebuilt automatically.
No git-graph performance improvement has been measured.

These are personal machine defaults. Binaries built with native CPU targeting may
require this CPU's capabilities elsewhere. For portable builds, override the flags,
for example with `RUSTFLAGS='' cargo build --release`. `CARGO_ENCODED_RUSTFLAGS`
takes precedence over `RUSTFLAGS`; either environment variable overrides the
configured target flags. Release profiles remain package-defined: no global LTO,
codegen-unit or panic override is installed.

Herdr still uses [its dedicated helper](herdr.md). The helper explicitly sets its
own Rust flags and release profile, selects a stable Git release, provisions the
matching Zig compiler, configures the native engine, and verifies the staged binary
before installation. A CPU default alone does not replace that workflow.

Sources: [Cargo configuration](https://doc.rust-lang.org/cargo/reference/config.html#buildrustflags), [install configuration discovery](https://doc.rust-lang.org/cargo/commands/cargo-install.html#configuration-discovery).
