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
  regardless. The controller has quirky firmware (`HCI Enhanced Setup
  Synchronous Connection command advertised, but not supported`). `main.conf` is stock;
  `/etc/bluetooth` is mode 555. Matches upstream bluez issue #1905 (many machines, after a
  firmware bump, benign).
- **Fix:** none (upstream bluez bug; no config affects the race).
- **Correction, 2026-09-18: the controller is Qualcomm, not MediaTek MT7922.** This entry
  previously named it MT7922. `btusb` is bound to USB `10ab:9309` (a USI module — the Bluetooth
  half of the same WCN6855 combo as the QCNFA765 wifi), `bluetoothctl show` reports
  `Manufacturer: 0x001d`, which is Qualcomm's Bluetooth SIG company ID, and there is **no
  MediaTek device on PCI or USB at all**. The likely source of the error is that `lsmod` shows
  `btmtk` loaded — but `btusb` pulls in every vendor helper (`btrtl`, `btmtk`, `btintel`,
  `btbcm`) regardless of which chip is present, so a loaded `btmtk` is not evidence of MediaTek
  hardware. Nothing else in this entry changes: the race, the A/B result and the acceptance all
  stand, since none of them depended on the vendor.
- **Recheck:** bluez update resolving #1905, or a BT controller firmware update.

---

## nvim additions investigated and DECLINED (2026-08-12)

Priced during the nvim audit and rejected. Recorded because each is the kind of thing an
audit will keep suggesting.

- **marksman** (markdown LSP) — **declined on cost/benefit.** 21 MiB plus a 70 MiB .NET
  runtime, for a link graph between files. Measured: 2 markdown links, 1 papis note, 0
  wiki-links, 0 cross-links across the whole repo. Not a prose linter — link integrity only.
- **CMake LSP** — **reversed on evidence, 2026-08-13: `neocmakelsp` went in.** 27 of 37
  CMake files are authored, not vendored, and the package needs only `cmake` at runtime plus
  the rust already installed for paru; `cmake-language-server` was 18 months idle, which is
  what "unmaintained" was guessing at. `neocmakelsp stdio`; formatting is external via
  `gersemi` (`python-gersemi`).
- **`taplo`** (TOML) — **tried and REMOVED, 2026-08-13.** Installed and verified working,
  then dropped: its pitch ("catches config that silently does nothing") only held for
  `uv.toml` — ruff already refuses to start on a bad `pyproject.toml` key, and taplo missed
  a misspelt `addoptss` under `[tool.pytest.ini_options]` and every non-schema TOML file
  entirely. Insurance firing maybe twice a year against 12 MiB and an install.sh entry.
- **`harper-ls`** (grammar) — **measured and REJECTED, 2026-08-13.** Handles LaTeX math
  better than Neovim's spellcheck, but its dictionary is worse for this vocabulary: 34 false
  flags on the real `main.tex` vs Neovim's 5, including `vorticity → voracity` and `Kalman`
  unrecognised. Neovim's tracked 466-word list already knows them; porting it and accepting
  a weaker dictionary isn't worth 112 MiB for what harper adds (repeated words, indefinite
  articles). If revisited, re-score with `~/learning/playground/harper-vs-spell` rather than
  re-deriving the comparison.
- **`g:rcsv_max_columns`** — deliberately unset; no CSV has been slow. Set only against an
  actual symptom. (`g:rcsv_align_mode`, which the config used to set, was never a real
  option.)
- **`queries/zsh/textobjects.scm`** — **done 2026-08-13.** Upstream's zsh query defined
  neither `@block` nor `@parameter.outer`; added both (`;; extends` first line is
  load-bearing). Bracket/class text-objects stay no-ops: shell has no class.

**jupytext stays per-venv**, installed only when a project needs notebooks, matching how
jupyter is handled generally — `.ipynb` opening as raw JSON is expected without it, not a
fault. `uv pip install jupytext` in the venv, then `:restart`. Confirmed working 2026-09-09;
the health warning is permanent by design and should not be re-raised as a finding.

---

## No system `blas` provider — ACCEPTED (2026-08-14)

`pacman -Qi blas` finds nothing, and `-lblas`/`-llapack` don't resolve. Deliberate, not a
gap — an audit will keep proposing a fix for it.

- **Investigated:** the AUR adapter `blas-aocl-gcc` (16 symlinks, 0 bytes of code) was the
  only package filling that slot. It was orphaned and dangling after AOCL 5.3.0 moved its
  trees to `MT/`; removed 2026-08-14. AOCL itself (maintained) is untouched and still this
  machine's BLAS — projects link it via CMake's `BLA_VENDOR=AOCL_mt`, which is *better*
  than the symlinks were (supplies `-fopenmp`, picks MT/ST + LP64/ILP64 correctly).
- **Why nothing replaced it:** no installed package declares a `blas` dependency.
  `blas-openblas` would fill the slot but would only ever serve a hypothetical consumer.
- **Accepted risk:** if a package ever does pull in `blas`, pacman resolves to netlib
  reference BLAS (~10x slower than AOCL) — visible in the transaction list, not silent.
- **Do not:** reinstall or fork `blas-aocl-gcc`. AOCL ships no `libblas.so` at all; `-lblas`
  was always the adapter's invention.
- **Recheck:** if `blas-aocl` is ever revived on the AUR for the `MT/` layout, or a wanted
  package starts depending on `blas`.

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

Measured while comparing against Omarchy. `sysup` refreshes four plugin ecosystems; three
pull and run whatever upstream pushed since the last run.

| Ecosystem | Repos | On disk | Pinned |
|---|---|---|---|
| `~/.local/share/nvim/lazy` | 37 | 126M | **yes** — `nvim/lazy-lock.json` |
| `~/.vim/plugged` | 14 | 7.4M | no |
| `~/.config/zsh/plugins` | 3 | 4.5M | no |
| `~/.config/tmux/plugins` | 3 | 2.6M | no |

57 repos, 40 distinct GitHub owners, ~140 MB executed at shell/editor/tmux startup — the
same risk class `containers/README.md` cites to justify the move off Docker, with the
plugin pull left off that list.

- **The split is an accident of which ecosystems ship lockfiles**, not a decision — tpm,
  vim-plug and the zsh updater simply have none.
- **Accepted:** pinning the other three means adopting a lockfile mechanism three more
  times for ~20 packages that are mostly completions and syntax highlighting, plus the
  same "lockfile age" follow-on work `config-drift` already does for nvim. Cost lands on
  every future update; benefit is against a supply-chain compromise of a named upstream.
- **Do not** "fix" the inconsistency by unpinning nvim — the lockfile is also the rollback
  path (`Lazy! restore`), which the other three lack entirely.
- **Recheck:** if tpm or vim-plug grows a lockfile, or one of the 40 owners is compromised.

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

Disabling thinking on `gemini-2.5-flash` was proposed as a free speedup. Measured with 15
API calls: the premise held, the conclusion didn't.

- **Thinking is not incidental.** One Kalman-crop call spent 1846 thinking tokens for 1046
  output tokens (55% of the request); `thinking_budget=0` cut total tokens 5937→2994 (50%)
  across three fixtures.
- **Rejected on accuracy, per a rule fixed before running** (same-config repeats were
  byte-identical, so the noise floor is ~zero). `budget=0` broke the LaTeX rule on the
  German fixture (`sigma_1` instead of `\sigma_1`) and completed a word the crop had cut
  off. It did preserve italic emphasis the current config drops — the differences run both
  ways, which is why the pre-registered rule decided it, not a post-hoc reading.
- Latency gains (12.1→10.7s, 4.6→2.3s, 3.4→1.4s) mostly sit inside the run-to-run noise
  (up to 1.42s); the token counts are the trustworthy number here.
- **`thinking_level` doesn't exist on this model** — the API rejects `MINIMAL`/`LOW`/etc.
  (`400 INVALID_ARGUMENT`); it's a Gemini 3 surface. Only `thinking_budget` applies here.
- **`max_output_tokens` is deliberately unset**, because thinking counts against it (a 256
  cap left only 13 tokens to answer) and the measured worst case is 5535 tokens — nothing
  below 8192 would be safe.
- **`thinking_budget=512` was separately measured and also rejected** (9 calls): dynamic
  thinking hallucinated 0/30 against a ground-truth fixture, `budget=512` hallucinated
  2/30, `budget=0` hallucinated 3/30 — monotonic, less thinking means more silent
  "correction" of the source (`Kalmann`→`Kalman`, `teh`→`the`).
- **Fix:** none. Keep dynamic thinking — the least-hallucinating configuration measured.
- **Recheck:** when `gemini-2.5-flash` is superseded; every number here is model-specific.

## gemini-3.5-flash-lite for capture-ocr — REJECTED (measured, 2026-09-08)

Priced identically to the `gemini-2.5-flash` this tool runs, so it looked like a free
upgrade. 40 API calls across four fixtures.

- **Faster and cheaper** (2.6x, 2.3x in practice — it does zero thinking) but **never
  repeats itself**: seven runs of the same image at temperature 0 gave seven distinct
  outputs, word count swinging 42% of maximum on the hardest fixture.
- **The variation is content loss, not reformatting** — a full equation system was absent
  in 4 of 7 runs, dropped silently with no marker, while `gemini-2.5-flash` was
  byte-identical in 4 of 5 runs on the same fixtures.
- Silent omission is the one failure an OCR tool can't have: there's no `finish_reason` or
  token signal for it, so nothing downstream can detect it.
- **Decision:** keep `gemini-2.5-flash`. Reliability outweighs the speed/cost win.
- **Recheck:** when a newer flash-lite reaches general availability, re-run the repeat test
  first — speed and price were never the deciding variable.

## gemini-3.8-flash for capture-ocr — REJECTED on cost (measured, 2026-09-08)

Checked for lecture-video frames (chalk handwriting, compressed, sometimes mixed with
rendered text) since every earlier decision was made on clean PDF pages. 16 API calls.
Handwriting was not the problem — both models transcribed chalk derivations essentially
perfectly. Where they differed:

| | 2.5-flash (kept) | 3.8-flash |
|---|---|---|
| Image tokens, same frame | 466 | **1286** |
| LQR weighting matrix `Q` | 2×2 — two entries lost | 4×4, correct |
| MATLAB line cut at pane edge | invented `(M*L) 0];` | faithful `(...` |
| burned-in subtitle | transcribed faithfully | omitted |

- **Rejected on cost, not quality:** 2.0–2.6× at introductory pricing, 3.9–5.1× after
  2027-01-01 — 3.8-flash tokenises the same image at 1286 vs 466 and thinks more.
- No regression on hallucination: both score 0/30 on the ten-trap fixture.
- Net: one real content error (self-detecting — a 4-state system can't have a 2×2 `Q`)
  against one thing 3.8-flash omitted. Neither model is reliably more literal; "which model
  invents cut-off text" flips by content type across the fixtures tested.
- **Decision:** keep `gemini-2.5-flash`. 2–5× for one corrected matrix isn't worth it.
- **Recheck:** the 2027-01-01 price change, or if the `Q`-matrix class of error starts
  costing real time. `gemini-3.5-flash` needs no test — more expensive than 3.8-flash
  while two generations older.
- **Method note:** a regex marker check misreported 3.8-flash as missing content it had
  written as `\text{lqr}(` instead of `lqr(` — verified before reporting; watch for this
  when scoring LaTeX output by regex.

## foot `[text-bindings]` for Shift+Enter — REJECTED as unnecessary (measured, 2026-09-08)

- **Proposed:** static `[text-bindings]` remaps in `foot.ini`/`tmux.conf`, on the claim
  (read off Omarchy's config, never probed here) that Shift+Enter is indistinguishable
  from Enter.
- **Why it doesn't transfer:** foot 1.28.0 implements the Kitty keyboard protocol, so an
  application negotiates disambiguation at runtime with no config needed; tmux already
  requests extended keys itself and `tmux.conf:95` declares `foot*:extkeys`. Omarchy needs
  the static form to support many terminals; this machine has one, and it already speaks
  the protocol.
- **Evidence:** confirmed 2026-09-08 that Shift+Enter inserts a newline in Claude Code both
  inside and outside tmux. Nothing changed in `foot.ini` or `tmux.conf`.
- **Do not adopt `[text-bindings]` later** — it's a static, unconditional remap that fires
  whether or not the application asked for disambiguation, breaking any program that
  expects a plain newline.
- **The one real gap found was narrower, in Neovim:** `completion.lua:106`'s
  `preselect = false` means `<CR>` on an unselected completion menu already inserts a
  newline; only a *selected* item accepts. Bound `<S-CR>` to cancel-then-newline in the
  nvim submodule (`43a82ee`).
- **Method note:** `cat -v` never sends the mode request, so it falsely reports "identical
  to Enter" — same shape as the `fc-match` artifact that withdrew finding 15.
- **Recheck:** only if foot loses Kitty-protocol support, or a tool needing the distinction
  stops receiving it.

## Omarchy's `dirmngr.conf` keyservers — DECLINED (measured, 2026-09-08)

- **Proposed:** copy Omarchy's five-keyserver `dirmngr.conf` so `paru`'s AUR-source GPG
  fetches don't stall silently.
- **Not a security feature, which decides it.** `makepkg` verifies AUR signatures by
  fingerprint, pinned in the PKGBUILD — a keyserver only delivers a key already named by
  fingerprint, so more keyservers buy availability, not integrity.
- **The real argument for it:** an unfetchable key tempts `--skippgpcheck`; availability
  that prevents disabling a check is indirectly worth something, but only if the failure
  happens.
- **It doesn't happen here:** zero key-import failures in the pacman log, 2025-11-20 to
  2026-09-08. The dirmngr failures that *do* exist belong to a different keyring entirely
  (pacman's own `dirmngr@etc-pacman.d-gnupg`) and are DNS failures —
  `connect-quick-timeout` only shortens a hang, not a DNS lookup, so more keyservers just
  means more instant failures.
- **Omarchy states no reason**, and gnupg's built-in default is already
  `hkps://keyserver.ubuntu.com` — the real choice is four extra keyservers, not "some vs.
  none".
- **Declined; nothing changed.** Same test that rejected `vm.page-cluster`: config
  defending a condition this machine doesn't have.
- **Recheck:** a `sysup` actually stalls on a key fetch, or a key import fails.

## Omarchy's Firefox picture-in-picture rule — DECLINED (verified, 2026-09-08)

Ours: one rule opening Firefox's PiP window floating, size/position left to niri. Theirs
(Hyprland): fixed geometry plus `pin = true` so it follows across workspaces.

- **`pin` is the half that makes PiP worth having, and niri has no equivalent** — the
  point of popping a video out is watching while working *elsewhere*, and without pin the
  window just sits on the workspace it opened on.
- **Verified 2026-09-08** against niri 26.04: `sticky`, `pinned`, `always-on-top`,
  `show-on-all-workspaces` and `follow-workspace-switch` are all rejected by
  `niri validate` (control: `block-out-from "screen-capture"` is accepted, so the probe
  would have caught a pin key had one existed).
- **Declined; nothing changed. Recheck** if niri gains a pin/sticky rule, or PiP starts
  landing somewhere annoying.

## `/etc/pam.d/ly` differs from the package — ACCEPTED, and not tracked (2026-09-08)

Ly (the display manager that starts niri) ships a PAM stack including GNOME
Keyring/KWallet/elogind hooks and an explicit `pam_systemd.so class=greeter`; the live
`/etc/pam.d/ly` is four lines of plain `include system-login`.

- **Accepted:** `system-login` still provides `pam_nologin.so` and `pam_systemd.so`, so
  the security-relevant behaviour is intact, and login demonstrably works (`loginctl`
  shows a properly registered session).
- **Caveat stated, not buried:** dropping `class=greeter` means the session registers via
  `system-login`'s generic `pam_systemd.so` line, not as a greeter class — a real runtime
  difference static comparison can't fully settle, and no symptom prompts testing it.
- **Not tracked, deliberately** — nobody knows why the file was simplified (predates this
  repo), and tracking would freeze an undecided state into a rebuild-any-machine repo.
  Restoring the package default was considered and rejected: unlike the same-day fwupd
  item, this is the login path, not a preference with an instant undo.
- **Recheck:** a `.pacnew` arrives for it, login behaviour changes, or greeter-class
  registration is ever wanted.

## Probe note — a template unit is not a missing unit

`systemctl is-enabled ly.service` returned `not-found`, read as "Ly isn't what logs this
machine in" — wrong: `ly` ships the template `ly@.service`, running as `ly@tty2.service`.
A missing unit and a wrongly-named one look identical. Check
`systemctl list-unit-files 'name*'` before concluding a unit doesn't exist.

---

## Repo-wide documentation sweep — ACCEPTED (2026-09-09)

Full pass over every markdown file outside `nvim/`: cross-file duplication, path-citation
validity and a sample of claims. Nothing to fix. One stale number was found and corrected
(`agent-skills.md` said `bash/` has 35 scripts; it has 38). Don't re-run the same
duplication/path-citation/claim probes expecting a different answer without a reason to
think something has drifted since.

---

## Tmux identity scope — ACCEPTED (2026-09-11)

Checked from the laptop: a pane in the local tmux server reaches the Debian Cloud VM fine,
advertising `tmux-256color` with correct colour. The local status identity stays hidden
correctly — it describes the server's startup context, not an individual pane's
destination.

For persistent VM work, a separate plugin-free server config displays `user@hostname`,
installed and confirmed on the VM. Testing `bash/tmux-identity` from an inbound-SSH tmux
server would exercise a supported edge case but isn't the chosen workflow, so it's not an
open TODO — its four branches remain fair regression-test scope if one is ever written.

---

## Test runner follow-on scope — DROPPED by the user (2026-09-16)

`bash/run-tests` was delivered. Three planned increments were dropped with the item and
should **not** be re-raised as gaps: invariant greps (no sudo in `install.sh`, no user unit
ordered against `network-online.target`, explicit background hex in `bash/tmux-theme`), a
fake-`tmux` test of `bash/tmux-identity`'s branches, and a process-state test of
`bash/lock-once`. All three conventions still hold; per `docs/omarchy-comparison.md`, write
a test for a concrete regression, not to match a count.

Still deliberately unasserted, and not a gap: the journal query in
`skills/diagnose-boot-or-suspend/references/incident-2026-09-02.md` — a test that fails when
the journal rotates is the tmux-power mistake in a new costume.

## 2026-09-02 incident's journal window is gone — corruption, not retention (2026-09-18)

`journalctl --since 2026-09-02 --until 2026-09-03` returns nothing; the oldest surviving
entry is `2026-09-03T00:16:03`. Not ordinary rotation — the journal held 189.6 MB against a
4 GB cap and 25 files against a 100-file limit, neither close to being reached. Several
`*.journal~` files dated 3–4 Sep suggest journald marked one corrupt and rotated it,
plausibly collateral from that night's failed suspend/resume (unproven). **Do not derive a
retention window from `SystemMaxUse` arithmetic alone** — the real window here was ~15 days
against a cap implying roughly ten months.

---

## mupdf instead of poppler for rga — REJECTED (tested, 2026-09-17)

`poppler` was removed 2026-07-10 as collateral of an unrelated `pacman -Rns` cascade,
silently breaking `rgbook` (poppler is rga's only PDF adapter) and `fbook`'s hidden-by-
default `pdfinfo` preview for two months. Printing removal stays deliberate; only the
casualty was unnoticed.

`mutool` is already installed for sioyek, so replacing poppler with it was tested rather
than assumed:

- **Extraction works standalone** — `mutool draw -q -F txt` produces the form-feed page
  breaks rga's `postprocpagebreaks` adapter needs.
- **Wiring it into rga doesn't.** rga has no mupdf adapter; a custom one plus wrapper is
  needed because rga feeds the file on stdin while mutool needs a seekable file with a
  `.pdf` extension. Four iterations didn't produce a working end-to-end result.
- **The deciding argument isn't the fiddliness** — the custom adapter would live in
  `~/.config/ripgrep-all/config.jsonc`, deliberately untracked, trading a packaged
  dependency for a hand-rolled one `config-drift` can't see.
- **And it's incomplete anyway** — mupdf doesn't replace `pdfinfo`, so `fbook`'s preview
  would stay broken without also moving `bash/vifm-pick` and `zsh/functions/pdf.zsh`.

**Decision:** keep `poppler` — reinstalling restores the state the code was written
against, it isn't a new dependency. **Recheck** only if poppler ever pulls in something
unwanted.

---

## `setsid -f handlr open` — CHECKED AND CLEAN (false alarm, 2026-09-17)

Briefly looked broken while diagnosing the pickers — `setsid -f handlr open <pdf>` seemed
to launch nothing. **It was the probe:** the test killed sioyek immediately before each
launch, and sioyek is single-instance, so the relaunch raced a shutting-down instance.
Re-tested three ways side by side; all launch correctly. Nothing to fix; recorded so it
isn't re-investigated.

---

## PID-1 scope protection for `sysup`'s paru run — DECLINED (measured, 2026-09-17)

Omarchy wraps its package transaction in a PID-1-owned system scope so a user-manager
teardown can't take the upgrade with it. Real concern in shape — `paru -Syu` and its
elevated pacman descendant both run under `user@1000.service`.

- **The trigger has never fired here:** `pacman.log` since 2025-11-20 shows 848
  transactions started, 848 completed, zero gap, and no interrupted/failed/lock-error
  lines. `user@1000.service` has `NRestarts=0` through three systemd upgrades.
- **No unprivileged version exists.** `systemd-run --system --scope` requires interactive
  root auth (reversing sysup's deliberate no-sudo-before-paru property); `--user --scope`
  lands inside the very cgroup it would need to escape. paru must also stay unprivileged
  for AUR builds, so the scope would need `--uid` plus preserved tty/cwd/env around the
  single most important command here.
- **Detection already exists** — `check_pacman_transaction` in `bash/config-drift` warns
  on a missing completion record, and `sysup` calls it after every paru run with a
  byte-precise boundary. This is a prevention gap, not a blind spot. Same shape as the
  `systemd-oomd` finding: Omarchy's reasoning is sound for their setup, wrong for this
  cgroup topology.
- **Reopen if** `user@1000.service` ever reports `NRestarts > 0`, or a started/completed
  gap appears in `pacman.log`.

---

## Package maintenance sweep: snap-pac, dosfstools, batsignal, brightnessctl, wlsunset — ACCEPTED (2026-09-17)

From a pass over all 183 explicitly-installed packages, checking build dates and upstream
activity. These five looked stale; none warranted a change once checked individually.

- **snap-pac** — upstream quiet since 2022, but it's only three pacman hooks wrapping
  `snapper create`; its whole dependency surface (hook format + `snapper` CLI) is stable.
- **dosfstools** — traced, not guessed: `/boot` is `vfat` with `fs_passno=2`, needing
  `fsck.fat` from this package, and it's `Optional For: grub, libblockdev-fs, udisks2`.
  Backs the bootloader and the USB mounting already in `docs/architecture/usb-media.md`.
- **batsignal** — quiet since 2024-06, but the obvious alternative `poweralertd` is worse
  on every axis checked (less active upstream, 17 vs 233 stars, needs `upower` as an extra
  daemon). Kept.
- **brightnessctl** — last pushed 2024-12 but the de facto Wayland standard; `light` isn't
  meaningfully better maintained and would just be a config rewrite for no gain.
- **wlsunset** — upstream moved to sourcehut (not `emersion`, corrected during the check),
  quiet but alive, version matches latest tag. `gammastep` adds features not needed here.

**Recheck:** any of these five repos gets archived, a real bug surfaces in daily use, or
Arch drops the package — not merely because upstream stays quiet another cycle.

---

## Three more warning-level journal lines — ACCEPTED (no observed symptom, 2026-09-17)

Found alongside the ath11k regulatory item, checked individually.

- **`foot: input: stray button release event (compositor bug?)`** — 6 times over ~17h
  uptime on the single niri-spawned foot server. User confirmed 2026-09-17: no observed
  mouse/click/scroll issue. Self-flagged as a possible compositor bug, so worth watching,
  but nothing to reproduce against.
- **`kernel: warning: 'Socket Thread' uses wireless extensions`** — a known Qt Bearer
  Management fingerprint (deprecated wifi-polling code), harmless: it's a Wi-Fi 7 warning
  and this machine's WCN6855 is Wi-Fi 6E.
- **`xdg-desktop-portal: Realtime error: Could not get pidns for pid 2`** — a Flatpak-
  detection probe failing because the kernel doesn't support that ioctl here. No
  corresponding realtime-audio symptom; pipewire's actual realtime setup goes through
  `rtkit` and is unrelated.

**Decision:** no action. Identified the source with no observed symptom — not proven
benign the way the bluez/libinput entries above were (no A/B, no reproduction).
**Recheck:** the foot line if a real click/scroll problem appears; the other two only if
their mechanism starts causing a visible failure.

---

## `GRUB_TIMEOUT=5` — ACCEPTED, keep the menu (2026-09-18)

Found during a services/daemon audit: the single largest software-controllable chunk of
boot time, and still not worth changing.

- **Measured:** `systemd-analyze` reports 10.274s firmware + 6.256s loader + 847ms kernel
  + 3.505s initrd + 4.255s userspace = 25.139s. The 6.256s loader phase is
  `GRUB_TIMEOUT=5`; dropping it to 1–2s would save ~4s per boot.
- **Why it stays:** that menu is the snapshot-recovery path — `grub-btrfsd` populates it
  from snapper snapshots, so shortening the window trades recovery margin (at the moment
  you most need it) for four seconds of an unattended boot.
- **Userspace isn't the problem.** 4.255s total; the slowest units (`rclone@` mounts,
  ~850ms each) are already decoupled from `graphical-session.target`, and `man-db.service`
  is timer-driven. The rest is device units settling, not services.
- **Decision (user, 2026-09-18):** leave it at 5. **Recheck** only if boot time becomes an
  actual complaint — this is the one place with seconds available.

## amdxdna NPU firmware missing — ACCEPTED, hardware deliberately unused (2026-09-18)

Every boot logs three `amdxdna` driver errors (`ret -2` = ENOENT) for firmware under
`amdnpu/1502_00/` that `linux-firmware` doesn't ship.

- **Not fixable by installing `xrt-plugin-amdxdna`** (in `extra`) — that's the userspace
  AIE/FPGA runtime, not the kernel firmware blob the driver wants.
- **Weak probe, stated rather than hidden:** `pacman -F amdnpu` returned nothing, but the
  file database wasn't synced first, so "nothing in the repos ships this" is likely, not
  established.
- **Decision (user, 2026-09-18):** the NPU isn't used and won't be, so nothing is being
  installed to satisfy an idle device. The driver gives up cleanly; nothing else refers to
  it.
- **Recheck:** if NPU acceleration is ever wanted, or a `linux-firmware` update starts
  shipping `amdnpu/` and the lines disappear on their own.

## ath11k regulatory-domain error — ACCEPTED, cosmetic (2026-09-18)

Closed from `TODO.md` item 4. Two boot-time errors (`Failed to set the requested Country
regulatory setting`, `failed to process regulatory info -22`) were blocked on testing
5GHz; the router has 5GHz, it was tested, and the error is confirmed cosmetic.

- **5GHz works, unchanged by the error.** Associated on channel 36 at 80 MHz width,
  −67 dBm, 18 dBm txpower against a 23 dBm ceiling. The error fires twice at boot exactly
  as before, so it plainly doesn't gate 5GHz.
- **Regulatory state is correct where checkable:** `iw reg get` gives `country DE:
  DFS-ETSI` with complete tables, including 6 GHz at 23 dBm — the one *real* WCN6855
  regulatory bug upstream (6 GHz silently vanishing) was fixed before kernel 6.8; this
  machine runs 7.2.6.
- **`no IR` on every 5GHz channel is normal, not the symptom** — it means no-initiating-
  radiation (no AP/IBSS/mesh on that channel), not "can't associate". Proven locally:
  channel 36 was marked `no IR` while the machine was connected on it.
- **DFS deliberately not pursued** — the only thing it would exercise (radar/channel-switch
  handling) would show up immediately in ordinary use as a drop if broken. Note it if a DFS
  channel is ever used naturally; don't go looking for one.
- **Working hypothesis, unproven:** `board_id 0xff` means no board-specific calibration
  table, so firmware rejects a country-set it has no slot for, while `cfg80211` (which
  actually governs this machine as a client) applies DE correctly.
- **Discriminator for next time:** genuinely broken WCN6855/QCNFA765 cases look like WMI
  timeouts, transmit-queue flush failures, wifi dying within 20s of boot, or a whole band
  missing. None occur here.
- **Probe note:** `iw dev wlan0 scan` needs root and fails `Operation not permitted` — an
  empty result isn't evidence of absence. `iw phy phy0 info` works unprivileged.
- **Recheck:** only if wifi actually misbehaves, or a DFS channel drops something.

Reference: [OpenWrt on `no IR`](https://forum.openwrt.org/t/what-does-no-ir-radar-detection-mean/98443),
[WCN6855 regulatory thread](https://www.spinics.net/lists/linux-wireless/msg254607.html).

## Sandboxing `rclone@.service` — NOT ATTEMPTED, wrong profile (2026-09-18)

The obvious next target after four notifier units were sandboxed, and the one unit that
**can't** take that profile. Recorded so the next audit doesn't rediscover this by
breaking a cloud mount.

- **`PrivateDevices=yes` is disqualifying on its own** — it disconnects mount propagation
  to the host, and rclone's entire job is making `~/Cloud/<remote>` visible externally via
  FUSE.
- **Three more directives invert too:** needs `/dev/fuse`, real `AF_INET`/`AF_INET6`, and
  write access under `$HOME` — so `ProtectHome`/`ProtectSystem` would both need relaxing.
- **Payoff is smaller too:** the notifier series guarded `net-notify` parsing
  attacker-broadcast SSIDs in bash; rclone is a maintained Go binary, not hostile-input
  shell code.
- **If ever attempted:** design a bespoke profile from a measured inventory, don't copy
  `battery-watch.service`. `NoNewPrivileges`, `RestrictRealtime`, `LockPersonality`,
  `UMask=0077` would transfer cheaply.
- **Still easy, low value:** `notify-failure@.service` only needs
  `ReadWritePaths=%h/.local/state/service-failures` — though breaking the failure notifier
  would ironically hide failures, so it deserves the same negative-control testing.

## Firewall review — the traps, not the posture (2026-09-18)

Prompted by a "is the firewall best practice" question. Three findings were fixed
(`69c8abd`, `f31ec68`, `fe119f3`); the ruleset itself was left alone. Only the reasoning
that would otherwise get re-derived wrongly is recorded — posture details are deliberately
kept out of this public repo.

- **`forward` policy `accept` is inert, not there for containers.** `ip_forward = 0` and
  no host bridge; rootless podman's networks live in a user netns so the host forward
  chain never sees container traffic. The old "so container networking works" claim in
  `etc/README.md` was wrong and corrected.
- **`rp_filter` needs no change, though the obvious probe says otherwise.** `conf/all`
  reads `0`, but the kernel takes the max of `all` and the interface, and `wlan0` inherits
  `2` from `default`.
- **`conf/all` doesn't harden existing interfaces; `conf/default` only seeds new ones.**
  With forwarding off, the kernel ORs `all` with `conf/<iface>`, so one interface left at
  `1` defeats an `all` of `0`. Confirmed by a cold boot: a freshly created `wlan0` came up
  at `0` under `systemd-sysctl`.
- **Probe note:** `nft list ruleset` needs root; unprivileged it fails silently, so an
  empty result isn't evidence of an empty ruleset.
- **Testing from another host: `nft add rule` gives a false pass.** `add` appends to the
  end of the input chain, *after* the rate-limited reject rule, so a test connection is
  rejected before reaching the new accept — looking like the firewall works when it was
  never exercised. Use `nft insert` (prepends), confirm placement with `nft -a list chain
  inet filter input`, and always run the positive control first (reach the service *with*
  the rule) so a failure means the firewall, not AP isolation or a wrong address. Confirmed
  2026-09-18 from off-machine, reject counter rising per SYN retry. Undo with
  `nft -f /etc/nftables.conf` (clean — the file opens with `destroy table inet filter`).

---

## Removed `mate-polkit` — DONE (2026-09-18)

TODO item 5. Dry-run verified beforehand (`pacman -Rsp mate-polkit` showed no cascade),
then run by the user.

- **Confirmed after the fact:** package gone, `polkit` (still needed by `fprintd fwupd
  rtkit udisks2`) untouched, no orphans, no leftover `.pacsave`/`.pacnew`.
- **Nothing else to clean up** — the XDG autostart entries it removed were already
  `OnlyShowIn`-gated and structurally inert under niri.
- **No GUI polkit agent added, deliberately.** 69 of 245 polkit actions are
  `implicit active: yes` (no prompt needed for a local session); the rest are reached only
  by CLI tools with their own agent (`pkttyagent`, `fwupdmgr`'s `FuPolkitAgent`). No GUI
  app here requests authorization.
