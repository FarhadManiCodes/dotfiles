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
- **`taplo`** (TOML) — **tried and REMOVED, 2026-08-13.** Installed, configured and
  verified working, then dropped once its real coverage was measured rather than assumed.
  The pitch was "it catches config that silently does nothing", the failure class this audit
  kept finding by hand. Measured, that holds for **`uv.toml` only**: `uv` accepts a misspelt
  `concurent-downloads` with exit 0 and no warning, and taplo flags it. It does **not** hold
  for the case actually used to justify it — **ruff refuses to start** on an unknown key
  (`Failed to parse pyproject.toml`), so there taplo is merely *earlier*, not new
  information. And coverage is patchy anyway: a misspelt `addoptss` under
  `[tool.pytest.ini_options]` produced **0 diagnostics**, because the pyproject schema does
  not reach into every tool's sub-table, and `handlr.toml` / `spotify-player/*.toml` /
  `icons/settings.toml` matched no rule at all. Verdict: insurance that fires perhaps twice a
  year, against 12 MiB plus a tracked config, an install.sh entry and a `--config` flag in
  `cmd`. Not worth carrying. Superseded detail, for anyone reconsidering: Not AUR-only as first
  recorded: **`taplo-cli` 0.10.0 is in `extra`**, 11.9 MiB, upstream healthy. Serves 12
  authored TOML files of which **7 are `pyproject.toml`** (papis-ask, paper-refinery,
  mathunicode, cv-generator, yts), where SchemaStore validation is the draw — the same thing
  `yamlls` already gives YAML. Nothing shadows it: the `toml` parser gives highlighting, but
  there is no validation today. Invocation `taplo lsp stdio`; **verify `taplo lsp --help`
  first**, since upstream warns the LSP is not in every build.
- **`harper-ls`** (grammar) — **measured and REJECTED, 2026-08-13. Installed, scored,
  uninstalled.** Not because it handles LaTeX badly — **it handles math better than Neovim
  does** — but because its dictionary is worse at this subject matter. On the real
  `main.tex` it flagged **34** where Neovim's spell flags **5** (all genuine unknown names),
  and it mis-suggests on domain vocabulary: `vorticity -> voracity`,
  `incompressible -> compressible`, `Kalman` unrecognised. All clean under Neovim's, because
  the tracked 466-word list knows them; adopting harper would mean porting that list to its
  `userDictPath` *and* accepting a weaker dictionary, for 112 MiB. With `SpellCheck = false`
  it still flagged 10 on that file via compound-word linters.

  **The genuine trade, worth keeping in mind if this is ever revisited:** neither parses
  LaTeX perfectly, and they fail on *opposite* constructs. Neovim leaks out of
  `\begin{align}` (flagged `Cx` in `y &= Cx + Du`) and out of `\texttt{}`; harper leaks out
  of `\begin{verbatim}` (flagged `recieve` in a code block). In practice the math leak is
  rare — zero occurrences in the real `main.tex` — while harper's vocabulary noise is
  pervasive. **This could flip** if the writing shifts to heavy `align`/`gather` with
  single-letter matrix names; try adding those tokens to the wordlist first. What harper
  genuinely adds and Neovim cannot: repeated words (`this this`) and indefinite articles
  (`a apple`) — real but small. Sentence capitalisation is *not* one, Neovim already catches
  it via `spellcapcheck`. Re-score with `~/learning/playground/harper-vs-spell` (fixtures,
  both configs, scoring table) rather than re-deriving any of this.

  Superseded first impression: Not the narrow tool first
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

**Confirmed 2026-09-09.** The user verified notebooks open as markdown in a venv that has
jupytext, and `TODO.md` §9 — which had raised the absence as an open question against the
superseded uv-tool plan — was closed against this entry rather than actioned. The health
warning is permanent by design; it should not be re-raised as a finding at the next audit.

---

## No system `blas` provider — ACCEPTED (2026-08-14)

`pacman -Qi blas` finds nothing, and `-lblas` / `-llapack` do not resolve. This is
deliberate, not a gap, and an audit will keep proposing a fix for it.

- **Investigated:** the AUR adapter `blas-aocl-gcc` — 16 symlinks, 0 bytes of code — was the
  only package putting AOCL in that slot. It is **orphaned** (`Maintainer: null`; last
  touched 2024-03-04, flagged out-of-date 2026-08-10), and AOCL 5.3.0 moved its trees to
  `MT/`,
  dangling all 13 of its hardcoded paths; `ldconfig` then pruned the four `.so.3` links.
  Removed 2026-08-14. AOCL itself (`aocl-gcc`, maintained, 3 maintainers) is untouched and
  is still this machine's BLAS — projects link it explicitly through CMake's native
  `BLA_VENDOR=AOCL_mt`, which is *better* than the symlinks were (it supplies the `-fopenmp`
  libflame needs, and picks MT/ST + LP64/ILP64 instead of hardcoding one combination).
- **Why nothing was installed in its place:** no installed package declares a `blas`
  dependency — checked across every entry in the local database. `blas-openblas` (official,
  `extra`) would fill the slot, but it would only ever serve a hypothetical future consumer,
  and would not be used by any project here.
- **Accepted risk:** if some package ever *does* pull in `blas`, pacman resolves it to
  netlib reference BLAS, which is roughly an order of magnitude slower than AOCL. It will
  appear in the transaction list, so the cost is visible at install time, not silent.
- **Do not:** reinstall `blas-aocl-gcc`, or fork it. AOCL ships no `libblas.so` at all, so
  `-lblas` was always the adapter's invention rather than something AMD supports.
- **Recheck:** if `blas-aocl` is ever adopted on the AUR and updated for the `MT/` layout,
  or if a wanted package starts depending on `blas`.

## AOCL `.pc` files hardcode a nonexistent prefix — ACCEPTED (upstream packaging bug)

`pkg-config --libs blis-mt` emits `-L/opt/aocl/5.3.0/gcc/MT/lib`, a path that does not exist
(`/opt/aocl/` contains only `gcc/`). Affects every AOCL module: `blis-mt`, `flame`,
`aocl-utils`, `fftw3*`.

- **Investigated:** AMD's tarball assumes a version-stamped install root; the AUR PKGBUILD
  relocates it to `/opt/aocl/gcc` without rewriting `prefix=` in the `.pc` files.
- **Fix:** none needed for CMake projects — they use `BLA_VENDOR=AOCL_mt` and never consult
  pkg-config. For a non-CMake build, override the variable:
  `pkg-config --define-variable=prefix=/opt/aocl/gcc/MT --libs flame`.
- **Recheck:** next `aocl-gcc` bump.

## `sysup` executes unpinned code from 40 upstreams — ACCEPTED (priced 2026-09-05)

Measured while comparing against Omarchy. `sysup` refreshes four plugin ecosystems; three of
them pull and run whatever upstream pushed since the last run.

| Ecosystem | Repos | On disk | Pinned |
|---|---|---|---|
| `~/.local/share/nvim/lazy` | 37 | 126M | **yes** — `nvim/lazy-lock.json` |
| `~/.vim/plugged` | 14 | 7.4M | no — `vim +PlugUpdate` |
| `~/.config/zsh/plugins` | 3 | 4.5M | no — `git pull --ff-only` |
| `~/.config/tmux/plugins` | 3 | 2.6M | no — `tpm update_plugins all` |

57 repositories, **40 distinct GitHub owners**, ~140 MB executed at shell, editor and tmux
startup. This is the same risk class `containers/README.md` enumerates to justify the move off Docker —
"an AUR `build()` during `sysup`, a PyPI package behind a `uv tool`, an AI CLI agent" — with
the plugin pull left off that list.

- **Investigated:** the split is an accident of which ecosystems ship lockfiles, not a
  decision. lazy.nvim pins because lazy.nvim has a lockfile; tpm, vim-plug and the zsh
  updater have none.
- **Accepted:** pinning the other three means adopting a lockfile mechanism three more times
  for 20 packages that are mostly completions and syntax highlighting — and it would need the
  same follow-on work `config-drift` already documents for nvim, where "behind upstream" stops
  being a meaningful signal and lockfile *age* has to be checked instead. The cost lands on
  every future update; the benefit is against a supply-chain compromise of a named upstream.
- **Do not:** conclude the ecosystems are inconsistent and "fix" it by unpinning nvim. The
  lockfile is also the rollback path (`Lazy! restore`), which the other three lack entirely.
- **Recheck:** if tpm or vim-plug grows a lockfile, or if any of the 40 owners is ever
  compromised.

## Firefox: portal Inhibit rejected on exit — ACCEPTED (portal backend limitation)

On exit, Firefox's internal session management requests a suspend/logout inhibit over D-Bus
(`org.freedesktop.portal.Inhibit`) so it can save state cleanly. The portal rejects it and logs
a warning.

- **Investigated:** `xdg-desktop-portal-wlr` implements only *idle* inhibition, unlike the
  GNOME and KDE backends which also implement suspend/logout inhibit. So the call is refused by
  design, not by fault. Firefox closes fine regardless — nothing is lost.
- **Not the same thing as `dom.screenwakelock.enabled`**, which is set to `false` for an
  unrelated reason: that pref blocks the *web* `navigator.wakeLock` API, while this is Firefox's
  own shutdown path. Turning one off does not silence the other.
- **Fix:** none short of switching portal backend, which would be a much larger change than the
  warning is worth.
- **Recheck:** if `xdg-desktop-portal-wlr` ever implements the full Inhibit interface, or if the
  portal backend changes for another reason.

## Swappiness 10 with zram-only swap — ACCEPTED (2026-09-06)

- **Investigated:** the comparison called 10 inherently wrong for zram and proposed
  Omarchy's 150. Kernel guidance instead makes the optimum workload-dependent; values
  above 100 are possible for in-memory swap, not mandatory. The default is 60.
- **Evidence:** during discussion, live swappiness was 10, zstd zram was the only swap
  (~19.5 GiB), swap-in/out counters were zero since boot, and current memory-pressure
  averages were zero. The user reports no problems and ordinary use rarely fills half RAM.
- **Accepted:** keep 10 and the existing zram setup. This is a reasonable working baseline,
  not a demonstrated optimum for future CFD. Do not change it solely to match Omarchy.
- **Recheck:** a representative CFD job produces memory pressure, sustained swap activity,
  poor desktop responsiveness, or an OOM event. Compare solver runtime and responsiveness
  alongside swap activity and zram's actual memory consumption. Allow physical-RAM headroom
  for the desktop; the zram device is not independent additional RAM.

Reference: [kernel swappiness guidance](https://docs.kernel.org/admin-guide/sysctl/vm.html#swappiness).

## Dirty-page writeback limits 5% / 10% — ACCEPTED (2026-09-06)

- **Investigated:** Omarchy uses fixed 64 MiB background and 256 MiB writer thresholds;
  this machine uses `dirty_background_ratio = 5` and `dirty_ratio = 10`, with both byte
  settings zero. The ratios use the kernel's eligible memory pool, so the original
  comparison's fixed ~2 GiB / ~5 GiB estimates are withdrawn. Time-based writeback also applies.
- **Evidence:** the user reports no write-related problems so far; current I/O-pressure
  averages were zero during discussion. Neither is evidence of optimality under future CFD.
- **Accepted:** retain 5% / 10%. Larger buffered bursts are not inherently a defect;
  Omarchy's smaller byte limits have no demonstrated benefit for this user's workload.
- **Recheck:** large CFD output, checkpoint writes or other write-heavy work causes desktop
  pauses or prolonged write stalls. Measure throughput, latency and I/O pressure on that
  workload before choosing fixed-byte limits. No configuration change now.

Reference: [kernel writeback guidance](https://docs.kernel.org/admin-guide/sysctl/vm.html#dirty-background-ratio).

## `thinking_budget=0` for capture-ocr — REJECTED (measured, 2026-09-08)

The review of `bash/capture-ocr` suggested disabling thinking on `gemini-2.5-flash`, since
transcription plausibly does not need it. Measured with 15 API calls; the claim's *premise*
held and its *conclusion* did not.

- **Thinking is not incidental here.** One call on a matrix-dense Kalman crop spent
  **1846 thinking tokens for 1046 tokens of output** — 55% of the request. Across three
  fixtures (real math crop, real prose crop, synthetic German), `thinking_budget=0` cut
  total tokens **5937 → 2994, a 50% reduction**, and the setting demonstrably took effect
  (`thoughts_token_count` was 0 in every B call).
- **Rejected on accuracy, per a rule fixed before running.** The same-config repeats were
  byte-identical (A-vs-A similarity 1.0000 on two fixtures), so the noise floor is ~zero and
  every difference is attributable. `budget=0` broke prompt rule 3 on the German fixture,
  emitting `$\text{sigma\_1} \ge \text{sigma\_2}$` where the current config correctly
  produces `$\sigma_1 \ge \sigma_2$` — literal text instead of the LaTeX the prompt asks for.
  It also completed words the crop had cut off ("has to kno" → "has to know"), i.e. supplied
  text that was not visible. Both are fidelity losses on an OCR tool.
- **Not uniformly worse.** `budget=0` preserved italic emphasis (`*singular values*`) that
  the current config drops, which prompt rule 4 arguably wants. The differences run both
  ways; that is why the pre-registered rule, not a post-hoc reading, decided it.
- **Latency is the weak half of the evidence.** Medians fell 12.1→10.7 s, 4.6→2.3 s and
  3.4→1.4 s, but the largest within-config spread was 1.42 s, so the big fixture's 1.4 s
  gain sits inside the noise. n=2 per cell detects only large effects. Token counts are
  near-deterministic and are the trustworthy number here; the latency figures are indicative.
- **Fix:** none. Keep the current config (dynamic thinking, no `thinking_config`).
- **`thinking_level` is not available on this model.** `MINIMAL`/`LOW`/`MEDIUM`/`HIGH` exist
  in the SDK but the API rejects them: `400 INVALID_ARGUMENT, Thinking level is not supported
  for this model`. It is a Gemini 3 surface; on `gemini-2.5-flash` the only knob is the
  integer `thinking_budget`. Recheck when the model is upgraded.
- **`max_output_tokens` is deliberately not set.** Thinking counts against it (verified: with
  a 256 cap the model spent 243 tokens thinking, leaving 13 to answer), so a cap must cover
  think + output. Measured worst case is a **full page at 3577 + 1958 = 5535 tokens**, and
  thinking on one fixed crop varied 1846 → 2727 across runs (+48%), so nothing below 8192
  is safe. A cap that low guards only against a runaway never observed here, while adding a
  real truncation failure mode. The truncation *detection* it exposed was a genuine bug and
  is fixed separately.
- **`thinking_budget=512` was then settled too, and also rejected (9 calls, 2026-09-08).**
  Once the priority was named as hallucination rather than cost, thinking became the thing
  protecting against it. Scored against a synthetic fixture with **exact** ground truth —
  a coined term, two deliberate typos, a misspelled famous name, a 7-digit decimal, a DOI,
  three reference numbers, and a line cut mid-word — over three runs each:

  | config | hallucinations | thinking | latency |
  |---|---|---|---|
  | **dynamic (current)** | **0 / 30** | 635 | 4.9 s |
  | `thinking_budget=512` | 2 / 30 | 414 | 3.5 s |
  | `thinking_budget=0` | 3 / 30 | 0 | 1.7 s |

  Monotonic: less thinking, more invention. Every failure was silently *correcting* the
  source — `Kalmann`→`Kalman` (2/3 at 512, 1/3 at 0), `symetric`→`symmetric` and `teh`→`the`
  (1/3 each at 0). All numeric content survived in every configuration, and no configuration
  completed the truncated word, so the earlier n=1 claim that `budget=512` invents cut-off
  words **did not replicate** and is withdrawn.
- **Fix:** none. `capture-ocr` keeps dynamic thinking, which is the least-hallucinating
  configuration measured.
- **Recheck:** when `gemini-2.5-flash` is superseded — every number here is model-specific.

## gemini-3.5-flash-lite for capture-ocr — REJECTED (measured, 2026-09-08)

Checked because `gemini-3.5-flash-lite` is priced **identically** to the `gemini-2.5-flash`
this tool runs — $0.30 in / $2.50 out — so a newer model looked like a free upgrade. 40 API
calls across four fixtures (real math crop, real prose crop, synthetic German, full page).

Everything except reliability favoured it:

- **2.6x faster** (17.8 s vs 46.7 s over four fixtures) and **2.3x cheaper in practice**
  ($0.0102 vs $0.0237), despite the identical list price — it does **zero thinking**, and
  thinking is billed as output. It also preserved italic emphasis that 2.5-flash drops.
- **But it never repeats itself.** Seven runs of the same image at `temperature=0.0` gave
  **seven distinct outputs** (sha256), on both hard fixtures. Word count swung 209-363 on the
  math crop (**42% of maximum**) and 981-1204 on the full page.
- **The variation is content loss, not reformatting.** Checking for ten content elements
  visible in the crop, the equation system, the "state variables" definition and the
  "n-vector" passage were **absent in 4 of 7 runs**. One run silently dropped ~21 lines
  including the whole system (12); the surrounding text read naturally, with no marker.
- `gemini-2.5-flash` over the same fixtures returned **byte-identical output in 4 of 5 runs**
  with constant word counts (490, 1039); the single outlier differed only in how it formatted
  equation (12), which it still labelled.

Silent omission is the one failure an OCR tool cannot have: unlike truncation there is no
`finish_reason` or token-count signal, so nothing downstream can detect it and the only check
is re-reading the source — the work the tool exists to avoid.

- **Decision:** keep `gemini-2.5-flash`. Reliability outweighs 2.6x speed and 2.3x cost here.
- **Also measured:** `gemini-2.5-flash-lite` is 16x cheaper and *was* reproducible, but it is
  out of scope by preference and additionally invented words the crop had cut off.
- **Two caveats on the method.** An earlier "perfectly deterministic" reading of 2.5-flash was
  n=2; at n=5 it is 4/5, so it is highly but not perfectly reproducible. And two markers
  (`transition matrix`, `gaussian`) read as absent from every 2.5-flash run alike — a constant
  transcription choice, not variation, and they do not affect the comparison.
- **Recheck:** when a newer flash-lite reaches general availability, re-run the repeat test
  first; speed and price were never the deciding variables.

## gemini-3.8-flash for capture-ocr — REJECTED on cost (measured, 2026-09-08)

Checked because the tool is also used on lecture video — pausing a control-theory
YouTube lecture and OCR'ing the blackboard — and **every earlier model decision was made
on clean PDF pages**, which does not transfer to a compressed video frame. 16 API calls:
two real lecture frames (chalk handwriting, speaker occlusion, and in one frame a MATLAB
window, so handwriting and rendered text in the same image), plus the hallucination
fixture, the Kalman crop and the German fixture.

**Handwriting was not the problem.** Both models transcribed chalk derivations
essentially perfectly — "Popov-Belevitch-Hautus", `ctrb`, `randn(n,1)`, λ, ∈ ℂ, ℝⁿ and
all three numbered points — and both scored full content-marker coverage on every run
(13/13 and 8/8). That was the open question and it is answered for both.

Where they differ on the frames:

| | 2.5-flash (kept) | 3.8-flash |
|---|---|---|
| Image tokens, same frame | 466 | **1286** |
| LQR weighting matrix `Q` | **2×2 — two diagonal entries lost** | 4×4, correct |
| MATLAB line cut at the pane edge | **invented `(M*L) 0];`** | `(...`, faithful |
| `rank[(A−λI) B]` LaTeX | malformed `[[A-λI) … ]]` | proper `bmatrix` |
| burned-in subtitle, incl. its "igen" typo | **transcribed faithfully** | omitted |
| `u=force` label | captured | dropped |

- **Rejected on cost, not quality.** Measured **2.0–2.6×** at introductory pricing and
  **3.9–5.1× once that ends on 2027-01-01**. Two factors compound: 3.8-flash tokenises
  the *same image* at 1286 prompt tokens against 466, and thinks more (1189 vs 617 on the
  identical fixture; 2564→4570 across two runs of one crop, a 78% swing). A rate-only
  estimate of 1.5× was wrong and is withdrawn.
- **No regression on the criterion that decided everything else:** 3.8-flash also scores
  **0/30** on the ten-trap hallucination fixture, preserving `zernathic`, `symetric`,
  `teh`, `Kalmann`, the DOI and every number. It matched on the German fixture too.
- **Be fair about how bad 2.5-flash actually was.** One real content error (the `Q`
  entries, the messiest handwritten element in the frame, and self-detecting since a
  4-state cart-pendulum cannot have a 2×2 `Q`), plus one invention that happened to
  produce *correct* MATLAB. Everything else on both frames was right, and it captured two
  things 3.8-flash dropped.
- **A tempting generalisation that the data does not support.** "Which model invents
  cut-off text" **flips by content type**: on the video frame 2.5-flash invented and
  3.8-flash was faithful; on the paper crop 3.8-flash completed and 2.5-flash was literal;
  on the hallucination fixture neither did. Neither model is reliably more literal.
- **Decision:** keep `gemini-2.5-flash`. 2–5× for one corrected matrix is not worth it.
- **Recheck:** the 2027-01-01 price change, or if lecture-frame capture becomes frequent
  enough that the `Q`-matrix class of error starts costing real time. `gemini-3.5-flash`
  needs no test — it is *more* expensive than 3.8-flash while two generations older.
- **Method caveat:** an intermediate marker check reported 3.8-flash missing content it
  had transcribed, because the pattern demanded `lqr(` where the model wrote `\text{lqr}(`.
  Verified before reporting; all runs were complete. Anything scored by regex against
  LaTeX output needs that check.

## foot `[text-bindings]` for Shift+Enter — REJECTED as unnecessary (measured, 2026-09-08)

- **Investigated:** comparison finding 16 proposed three lines — two `[text-bindings]`
  entries in `foot/foot.ini` and `extended-keys-format csi-u` in `tmux.conf` — on the
  grounds that "Shift+Return sends the same bytes as Return and no application can tell
  them apart". That conclusion was read off Omarchy's config, never probed here.
- **Why it does not transfer:** foot 1.28.0 implements the Kitty keyboard protocol
  (`foot-ctlseqs.7` documents the full `CSI > flags u` push/pop/query set), so an
  application negotiates disambiguation at runtime and gets `CSI 13;2u` with no config.
  `man tmux` states tmux "will always request extended keys itself if the terminal
  supports them", and `tmux/tmux.conf:95` already declares `foot*:extkeys`. Omarchy needs
  the static form because they support many terminals; this machine has one, and it
  already speaks the protocol.
- **Evidence:** user-confirmed 2026-09-08 that Shift+Enter inserts a newline in Claude
  Code **both inside and outside tmux**. So both hops carry it and neither setting is
  needed. Nothing was changed in `foot.ini` or `tmux.conf`.
- **Do not adopt the `[text-bindings]` form later.** It is a static, unconditional remap:
  it fires whether or not the application asked for disambiguation and never reverts, so
  a program that today gets a plain newline would instead receive `\e[13;2u`. The
  protocol path is negotiated per application and pops back on exit.
- **Not a defect anywhere:** IPython, ptpython and psql never request the distinction and
  bind nothing to it, so "no difference" there is correct behaviour, not a symptom. Only
  Claude Code and codex are meaningful tests of this.
- **What did come out of it:** the one real gap was in Neovim, and it was narrower than
  first argued — `completion.lua:106` sets `preselect = false`, so `<CR>` on an open but
  unselected menu already inserts a newline. Only a *selected* item makes `<CR>` accept.
  Bound `<S-CR>` to cancel-then-newline in the nvim submodule (`43a82ee`), replacing
  `<C-e>` then `<CR>`.
- **Method note:** `cat -v` is the wrong probe for this. It never sends the mode request,
  so it reports "Shift+Enter is identical to Enter" — confidently, about a question no
  application asks. Same shape as the `fc-match` artifact that withdrew finding 15.
- **Recheck:** only if foot is replaced by a terminal without Kitty-protocol support, or
  a tool that needs the distinction stops receiving it.

## Omarchy's `dirmngr.conf` keyservers — DECLINED (measured, 2026-09-08)

- **Proposed:** copy Omarchy's `default/gpg/dirmngr.conf` — five `hkps://` keyservers plus
  `connect-quick-timeout 4` — on the theory that `paru`'s `gpg --recv-keys` for AUR source
  packages inherits dirmngr's defaults and is where a `sysup` can stall with nothing to say.
- **It is not a security feature, which is the part that decides it.** `makepkg` verifies an
  AUR source signature against a key whose **fingerprint** the PKGBUILD pins in
  `validpgpkeys`. A keyserver is only the delivery mechanism for a key already named by
  fingerprint, so a hostile or merely wrong keyserver cannot substitute another key — the
  fingerprint check fails. Five keyservers buy availability, not integrity.
- **The strongest argument for it, recorded because it is real:** if a key cannot be fetched
  at all, the temptation is `--skippgpcheck`. Availability that stops you disabling a check is
  indirectly security-relevant. It only pays off if the failure happens.
- **Evidence that it does not happen here:** zero key-import failures in the whole pacman log,
  2025-11-20 to 2026-09-08 — no "unknown public key", no "keyserver receive failed". The only
  gpg lines are routine keyring-package updates.
- **The dirmngr failures that do exist are the wrong keyring and the wrong failure.** Two
  bursts, 2026-08-07 12:55 and 2026-08-17 11:19, each inside one minute, all
  `can't connect to 'archlinux.org': host not found`. They belong to
  `dirmngr@etc-pacman.d-gnupg` — pacman's keyring, which has its own
  `keyserver-options timeout=10` and is untouched by this file. And `connect-quick-timeout`
  shortens a connect that *hangs*; DNS failure returns immediately, so there is nothing to
  shorten. More keyservers with no DNS is more instant failures.
- **Omarchy states no reason** — no comment in the file, nothing in their docs, and they ship
  the identical file twice (`default/gpg/` and `etc/gnupg/`). Inferring from shape only: a
  distribution across many users and networks carries a support burden from keyserver
  flakiness that one machine on a stable connection does not.
- **Also note gnupg's built-in default is already `hkps://keyserver.ubuntu.com`** — Omarchy's
  own first line. The choice is four extra keyservers, not "some versus none".
- **Declined; nothing changed.** No `dirmngr.conf` exists here, in `/etc/gnupg` or `~/.gnupg`.
  Config defending a condition this machine does not have — the same test that rejected
  `vm.page-cluster` and downgraded the free-space precheck.
- **Recheck:** a `sysup` actually stalls on a key fetch, or a key import fails.

## Omarchy's Firefox picture-in-picture rule — DECLINED (verified, 2026-09-08)

- **What PiP is:** Firefox pops a playing video into a small floating window that stays on
  top, so it keeps playing while you work in another window.
- **Ours:** one rule matching `firefox$` + title `^Picture-in-Picture$` with `open-floating
  true`, so size and position are whatever niri chooses.
- **Theirs (Hyprland):** fixed 600x338, top-right with a 40 px margin, no border, and
  `pin = true` so the window follows across workspaces.
- **`pin` is the half that makes PiP worth having, and niri has no equivalent.** The point of
  popping a video out is to keep watching *while working elsewhere*, and on niri "elsewhere" is
  another workspace. Without pin the window stays on the workspace it was opened on, so the
  geometry rules would be styling a window that is not on screen.
- **Verified 2026-09-08 against niri 26.04 (8ed0da4)**, by inserting each key into the real PiP
  rule and running `niri validate`: `sticky`, `pinned`, `always-on-top`,
  `show-on-all-workspaces` and `follow-workspace-switch` are all **rejected**. Control:
  the unmodified config validates, and `block-out-from "screen-capture"` is **accepted** — so
  the probe would have found a pin key had one existed.
- **Declined; nothing changed.** Revisit if niri gains a pin/sticky window rule, or if PiP
  starts landing somewhere annoying.

## `/etc/pam.d/ly` differs from the package — ACCEPTED, and not tracked (2026-09-08)

- **What it is:** Ly is the TUI display manager that logs this machine in and starts niri.
  `/etc/pam.d/ly` is its PAM stack. Confirmed running: `ly@tty2.service` is active, and the
  live session reports `Service=ly`, `Type=wayland`, `seat0`.
- **The difference** (recorded 2026-09-06 against `ly 1.4.1-1`): the live file is four lines,
  each `include system-login`, where the package includes `login` and adds optional GNOME
  Keyring, KWallet and elogind hooks plus an explicit `pam_systemd.so class=greeter`.
- **Why it is accepted:** `system-login` still provides `pam_nologin.so` and `pam_systemd.so`,
  so the security-relevant behaviour is intact — read directly from
  `/etc/pam.d/system-login`. The removed hooks are for software that is not installed. And it
  demonstrably works: `loginctl` shows a properly registered session.
- **The caveat, stated rather than buried:** `pam_systemd.so` *is* installed, so dropping the
  explicit `class=greeter` registration is not merely deleting a hook for absent software.
  `system-login`'s generic `-session optional pam_systemd.so` still runs, so the session is
  registered but not as a greeter class. Static comparison cannot establish the runtime
  effect of that, and no symptom prompts a test.
- **Not tracked, deliberately.** Nobody knows *why* the file was simplified — it predates this
  repo — so tracking would freeze an undecided state into a repo meant to rebuild any machine.
- **Restoring the package default was considered and rejected.** The fwupd item the same day
  showed that returning to a default can remove a modified file entirely, which is attractive.
  It does not transfer here: fwupd was a preference with an instant undo, this is the path that
  lets you log in, and the payoff would be one fewer line in a baseline. "Differs from the
  package" is not a defect.
- **Recheck:** a `.pacnew` arrives for it, login behaviour changes, or a reason to want
  greeter-class session registration appears.

## Probe note — a template unit is not a missing unit

`systemctl is-enabled ly.service` returned `not-found`, which read as "Ly is not what logs this
machine in". Wrong: `ly` ships `ly@.service`, a **template**, and the running instance is
`ly@tty2.service`. The same shape as the typo'd `journalctl -u` already in `docs/system-notes.md` — a
missing unit and a wrongly-named one are byte-identical in the output. Check
`systemctl list-unit-files 'name*'` before concluding a unit does not exist.

---

## Repo-wide documentation sweep — ACCEPTED (the reference docs are not bloated)

Run 2026-09-09 across all 28 markdown files outside `nvim/` (5,508 lines), after the
always-loaded agent files were collapsed. Recorded because the result is a **negative** one,
and without it the same three probes get re-run and re-derive the same nothing.

**Cross-file duplication — clean.** Comparing substantive prose lines (>45 chars, non-list)
between every pair of files, the total overlap is **5 lines** (`docs/architecture.md` ↔
`docs/system-notes.md`, both extraction headers) plus 3 between `TODO.md` and
`skills/local-postgres/SKILL.md`, which is the `psql` example item 12 discusses.

```bash
# substantive-line overlap between every pair of docs
python3 -c "$(cat <<'PY'
import glob,itertools,re
f=[x for x in glob.glob('**/*.md',recursive=True) if not x.startswith('nvim/')]
n=lambda p:{re.sub(r'\s+',' ',l).strip() for l in open(p) if len(l)>45 and not l.lstrip().startswith(('|','#','-','*','`'))}
S={x:n(x) for x in f}
[print(len(S[a]&S[b]),a,b) for a,b in itertools.combinations(f,2) if len(S[a]&S[b])>=3]
PY
)"
```

**Path citations — clean.** Every repo-relative path in backticks, resolved against the repo
root *and* the citing file's own directory. The 78 that do not resolve are all legitimate:
Omarchy-repo paths (`install/`, `default/`, `themed/`), system paths (`mkinitcpio.conf`,
`logind.conf`), deliberately-deleted files (`fix-wifi.sh`, `zsh/archive/`), untracked-by-design
files (`rclone.conf`, `git/config.local`), and runtime artifacts (`chunks.json`,
`.venv/bin/python`). **The probe is not blind** — the same check found nine genuinely broken
`CLAUDE.md` pointers the day before, which were fixed.

**Claims — verified by sample.** `go` absent, `rust`/`qpdf`/`shellcheck-bin` present, no
`blas` provider and no `/usr/lib/libblas.so`, `zram0` exactly 20,955,443,200 bytes, 7 fstab
subvolumes, 37 lazy plugins, btop pinned to `tokyo-night`, `postgresql-libs` explicitly
installed, no `userContent.css`. All hold. One stale number found and fixed:
`agent-skills.md` said `bash/` has 35 scripts; it has 38.

**What this does not cover.** The claim check is a *sample*, not exhaustive — measurements
with dates (benchmark figures, journal counts, package sizes) were not re-run, and several
cannot be without root or without the original journal window. `nvim/` was excluded and is a
separate pass. The bloat that was found was concentrated in one closed document
(`agent-skills.md`, 965 → 216) rather than spread across the references.

### Second pass, 2026-09-09 — the files the first pass had not read

The first pass ran the three probes over every file but only *read* a handful. This covers the
rest, and again found nothing to fix.

**`skills/` (860 lines) is mechanically clean.** `bash/check-skills` asserts frontmatter shape,
`references/*.md` existence and `bash/*` tool existence and executability — but **not external
commands**, so those were checked separately: `grim`, `slurp`, `psql`, `podman`, `papis`,
`refinery`, `uv`, `snapper`, `btrfs`, `niri`, `rclone`, `magick` all resolve.

Two apparent failures were the probe's fault, and are worth recording as instances of the
second rule: `pask` reported missing because `command -v` was run from **bash** and `pask` is a
**zsh function**; `papis-ask` reported missing because it is not a binary at all — it appears
only as a trigger word in a skill description, and the command is `papis ask`.

**App README claims verify.** `bash/sioyek` is 3 lines, the real 46 MiB binary is at
`~/.local/share/sioyek/sioyek`, `~/.local/bin/mutool` is byte-identical to the sioyek build
artifact, and `vifm/vifmrc:149` does use it. Podman runs `runc` with `criu` absent, graphroot
`/var/lib/docker`, `pg.service` active, `DefaultDependencies=false` inside `[Quadlet]` and not
`[Unit]`. `niri validate` passes against the tracked `config.kdl`.

---

## Tmux identity scope — ACCEPTED (2026-09-11)

The normal remote workflow was checked from the laptop: a pane in the locally started tmux
server connected successfully to the Debian Google Cloud VM, advertised `tmux-256color`, and
rendered colour correctly. The local status identity appropriately stayed hidden because it
describes the tmux server's startup context, not the destination of an individual pane.

For persistent work on the VM, a separate plugin-free server configuration now displays
`user@hostname`; it was installed and visually confirmed on the VM. The VM does not need the
laptop's desktop-oriented tmux configuration. Testing `bash/tmux-identity` from a tmux server
started after an inbound SSH login to the laptop would exercise a supported edge case, but it
does not represent the chosen workflow and no longer warrants an open real-use TODO. Its four
branches remain appropriate regression-test scope for the planned test runner.
