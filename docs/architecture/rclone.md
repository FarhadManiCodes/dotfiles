# rclone — Google Drive uses a personal OAuth client

**Done 2026-08-09.** `gdrive` has its own `client_id`/`client_secret` (GCP project
`rclone-personal`, Desktop-app client, app published, unverified). Google is going to
start charging for API calls on rclone's built-in client, so rclone disables its own
default client-ID in a release (announced 2026-07-06); the risk was a routine `sysup`
pulling that release and stopping `rclone@gdrive` on next start.

**Nothing was ever actually broken** — zero 403s and zero rate-limit errors in the entire
journal for both units. The migration is pre-emptive; don't re-justify it on a quota
problem that never happened.

**`Dropbox` still uses rclone's shared client, deliberately** — the retirement covers
Drive and Photos only. If a Drive/Photos remote is ever added, four traps, all silent:

- **Publish the app** (Audience → PUBLISH APP) — a Testing-status app issues refresh
  tokens that expire in 7 days, so the mount authenticates fine and dies weekly.
- **Pass `config_refresh_token=false`** to `rclone config update`, or it tries to refresh
  the *old* token against the *new* client and you can't tell which half failed.
- **Scopes go in "Manually add scopes"** on the *Data Access* page — Google's picker
  doesn't list them, and the console has moved to Google Auth Platform, so most guides
  describe a menu that no longer exists.
- Application type **Desktop app** — loopback `127.0.0.1:53682` is implicit, no redirect
  URI to register. Answer `n` to "Configure this as a Shared Drive?".

```bash
systemctl --user stop rclone@gdrive.service
rclone config update gdrive client_id=ID client_secret=SECRET config_refresh_token=false
rclone config reconnect gdrive:        # y to "replace it?"; opens 127.0.0.1:53682
systemctl --user start rclone@gdrive.service
```

Success is the `NOTICE: ... shared Google Drive client_id` line **disappearing** from
`rclone about gdrive:` — there are no errors to "stop".

**The `gdrive` remote is a `combine`, not the raw Drive — and this is not in the repo.**
`rclone.conf` is untracked (tokens), so a rebuild recreates a full-Drive remote and
silently undoes this. Recreate by hand:

```ini
[gdrive-full]        # the real Drive remote — NOT mounted
type = drive
...

[gdrive]             # what gets mounted at ~/Cloud/gdrive
type = combine
upstreams = FAU=gdrive-full:FAU Documents=gdrive-full:Documents tmp-office=gdrive-full:tmp-office
```

`combine` rather than mounting a subfolder, because it keeps every existing path valid —
the niri startup indexer and `bash/book-resources` want `~/Cloud/gdrive/FAU/Library`, and
`bash/gdocs-open` wants `gdrive:tmp-office`. (A fourth consumer, `study-library-sync`,
wanted `gdrive:FAU/Library` until it was removed 2026-09-18 in favor of a static local
mirror at `~/.local/share/study-library` — no sync timer or cache file, updated by hand,
so the book picker works offline too.) What stops being reachable through the filesystem
is the other seven top-level Drive folders, still reachable through `gdrive-full:`.

**Be honest about what that buys.** It shrinks the *filesystem* blast radius — an
accidental `rm -rf`, or malware walking mounted paths, can't reach the folders above. It
does **not** restrict the credential: `gdrive-full:` is in the same config file, so
anything that can read `rclone.conf` can still `rclone delete` any of them via
`gdrive-full:`. Reduction against accidents and dumb malware, not a targeted attacker.

**Trash can't be locked away from this machine, and rclone's delete guards don't apply to
mounts.** `--max-delete`, `--backup-dir`, `--dry-run`, `--interactive` are sync/copy/move
flags; a `rm` on a FUSE mount is a POSIX unlink and none of them fire. Drive's trash (30
days) is the only net — and `rclone cleanup gdrive-full:` empties it permanently, with
the same token. No OAuth scope grants read/write to existing files while withholding
trash management. So provider trash guards against *accidents*, never a compromised
token — only an off-machine append-only backup changes that, and there isn't one yet.

**Never run `rclone config show <remote>` — it prints the tokens in full.** Happened
2026-09-02 and forced a rotation (revoke at `myaccount.google.com/permissions` *first*,
then reconnect — reconnecting alone leaves the old refresh token valid). To read one
setting safely:

```bash
rclone config show gdrive | awk -F' = ' '$1=="type"{print $2}'
```

`~/.config/rclone/rclone.conf` holds the tokens and is intentionally untracked.
