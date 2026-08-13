# Revisit

Investigated issues, **accepted** — nothing to do. The first group was diagnosed to a
non-config root cause (hardware/firmware or upstream bug); the last entry records tools
that were priced and declined, so they are not re-proposed. Recheck the listed trigger on
the next relevant upgrade.

---

## libinput: event lag after resume from s2idle — ACCEPTED (healthy)

libinput logs `event processing lagging behind by ~1.3s, your system is too slow` on
Lid Switch / Power Button / keyboard at the instant of resume.

- **Investigated:** s2idle is the only sleep state (`/sys/power/mem_sleep` = `[s2idle]`;
  no s3 on this AMD platform). Hardware sleep is actually excellent — `last_hw_sleep`
  ≈ 276.8 s over a 277 s suspend (~99.9 % s0i3 residency), `amd_pmc` loaded. The lag is
  the intrinsic s2idle clock-gap: `CLOCK_MONOTONIC` keeps running across sleep, so on
  resume libinput sees overdue timers/events and complains. Purely cosmetic; input works.
- **Fix:** none (would need s3 — absent on this hardware — or a libinput change).
- **Recheck:** kernel / BIOS firmware update enabling s3, or a libinput update.

---

## wireplumber: UPower battery warning at boot — ACCEPTED (cosmetic)

One line per boot: `Failed to get percentage from UPower: NameHasNoOwner`.

- **Investigated:** the bluez5 SPA plugin reports the *host* (laptop) battery to BT
  headsets via Apple's HFP extension (`AT+IPHONEACCEV`), reading it from UPower. UPower
  is intentionally not installed. D-Bus already replies `NameHasNoOwner` (= not present);
  pipewire handles it gracefully, skips the feature, and watches for UPower to appear —
  everything else works. No per-feature toggle exists in pipewire 1.6 (checked the full
  `bluez5.*` property set; `hfphsp-backend=none` does **not** gate it — tested), and
  there is no alternative interface (UPower is the only host-battery source). It's simply
  logged too loudly (warning vs debug).
- **Fix:** none clean. Accept (chosen), or install `upower` (rejected — extra daemon).
- **Recheck:** pipewire/wireplumber update lowering the log level (Debian bug #1089234).

---

## bluetoothd: Failed to set default system config for hci0 — ACCEPTED (upstream race)

One line at (cold) boot. Bluetooth works fully — all A2DP endpoints register.

- **Investigated:** a nondeterministic timing race, **not** a config issue — proven by
  A/B testing. The error hits on cold boot and some warm restarts, but 5/5 warm restarts
  on *stock* config **and** 5/5 with an explicit `PageTimeout` both passed, so the
  parameter is irrelevant. btmon shows the `Set Default System Configuration` MGMT command
  actually succeeds (`Status: Success`) when sent — bluez logs the failure spuriously
  regardless. Controller is MediaTek MT7922 with quirky firmware (`HCI Enhanced Setup
  Synchronous Connection command advertised, but not supported`). `main.conf` is stock;
  `/etc/bluetooth` is mode 555. Matches upstream bluez issue #1905 (many machines, after a
  firmware bump, benign).
- **Fix:** none (upstream bluez bug; no config affects the race).
- **Recheck:** bluez update resolving #1905, or a BT controller firmware update.

---

## nvim additions investigated and DECLINED (2026-08-12)

Priced during the nvim audit and rejected. Recorded because each is the kind of thing an
audit will keep suggesting.

- **marksman** (markdown LSP) — **declined on cost/benefit.** 21 MiB plus
  `dotnet-runtime-9.0` at 70 MiB, i.e. a .NET runtime on the machine, and its entire value
  is the *link graph between files*. Measured: **2** markdown links between `.md` files in
  all of dotfiles, **1** papis note, **0** wiki-links, **0** cross-links. Same shape as
  preferring `shellcheck-bin` over the Haskell-linked repo build. It is not a linter — link
  integrity only, nothing about prose.
- **CMake LSP** — **reversed on evidence, 2026-08-13: `neocmakelsp` is going in.** The
  original "declined" rested on two things that did not survive checking. First, the need is
  real: **27 of 37** CMake files are authored (SciCpp's `chapters/*/` tree, toy-pde-solver's
  `src`+`tests`, three playground projects) — the count only looked inflated because the
  *largest* files on disk are vendored spack/git ones. Second, the cost is near zero:
  `neocmakelsp` needs only `cmake` at runtime and builds with the **rust already installed**
  for paru. Upstream is alive — v0.11.0 on 2026-07-25, pushed daily, 424 stars — whereas
  `cmake-language-server` was **last pushed 2025-02-11, 18 months idle**, which is what
  "unmaintained" was guessing at. Ignore `neocmakelsp-bin` (0.6.22, April 2024, dead).
  Invocation is `neocmakelsp stdio`; config is `init_options` plus its own
  `.neocmake.toml`/`$XDG_CONFIG_HOME/neocmakelsp/config.toml`. Formatting is **external** —
  `[format] program = "gersemi"`, so `python-gersemi` (extra) is required for `<leader>cf`.
- **`taplo`** (TOML) — **accepted 2026-08-13, pending install.** Not AUR-only as first
  recorded: **`taplo-cli` 0.10.0 is in `extra`**, 11.9 MiB, upstream healthy. Serves 12
  authored TOML files of which **7 are `pyproject.toml`** (papis-ask, paper-refinery,
  mathunicode, cv-generator, yts), where SchemaStore validation is the draw — the same thing
  `yamlls` already gives YAML. Nothing shadows it: the `toml` parser gives highlighting, but
  there is no validation today. Invocation `taplo lsp stdio`; **verify `taplo lsp --help`
  first**, since upstream warns the LSP is not in every build.
- **`harper-ls`** (grammar) — **open, decide by measurement.** Not the narrow tool first
  assumed: it ships dedicated `harper-tex` and `harper-typst` crates, and `backend.rs`
  dispatches `"typst"` and `"tex"|"latex"` to them, so it could *replace* Neovim's spell
  rather than merely duplicate it. `harper` 2.7.0 is in `extra`; 112 MiB but with **no
  runtime deps beyond glibc** — unlike marksman, which is smaller only until you count its
  70 MiB .NET runtime. Two questions settle it, both cheap on a real `.tex`: does it avoid
  flagging `\mathbf`/`\frac` (our treesitter route leaked those **648×** on the papis
  corpus), and how much of the 453-word list would need porting to its `userDictPath`? Win
  the first with a manageable second and it replaces the spell setup; otherwise skip it,
  since grammar alone was not judged worth the size.
- **`g:rcsv_max_columns`** — the one real knob for wide-CSV performance (default 30, caps
  rainbow highlighting). Deliberately **unset**: no CSV has been slow. Set it only against
  an actual symptom, and note that `g:rcsv_align_mode` — which the config used to set — was
  never an option at all.
- **A local `queries/zsh/textobjects.scm`** — **done 2026-08-13**, no longer deferred.
  Upstream's zsh query defines neither `@block` nor `@parameter.outer`, so `ab`/`ib` and `aa`
  were no-ops in shell files. Added both, same approach as `queries/sql/textobjects.scm`.
  The `;; extends` first line is load-bearing — without it the file replaces upstream's query
  rather than adding to it. `ac`/`ic` and `]] [[ ][ []` stay no-ops deliberately: shell has
  no class.

**jupytext is installed per-venv, when notebooks are actually needed** — not as a uv tool
and not system-wide, matching how jupyter is handled here generally. So `.ipynb` opening as
raw JSON is the **expected** state most of the time, not a fault: the spec resolves the CLI
venv-first and only arms the plugin when one exists, precisely because its read path
truncates notebooks when the binary is missing. `uv pip install jupytext` in the project
venv, then `:restart`. `:checkhealth jupytext` reports which binary it found, or warns that
notebooks will open as JSON.
