# btrfs subvolume layout — what it is for

`/etc/fstab` mounts seven subvolumes off one filesystem: `@` → `/`, `@home`,
`@snapshots` → `/.snapshots`, `@log` → `/var/log`, `@pkg` → `/var/cache/pacman/pkg`,
`@docker` → `/var/lib/docker`, `@postgres` → `/var/lib/postgres`.

The point is **exclusion from snapshots**, and it's load-bearing — without `@docker` and
`@pkg`, image layers and the package cache would be captured in every snapshot.

**The two snapper configs do different jobs**, not the way most setups assume:

- **`root`** — `TIMELINE_CREATE="no"`, `NUMBER_LIMIT=10`. `/.snapshots` holds only the
  pre/post pairs `snap-pac` takes around each pacman transaction. There are **no** hourly
  snapshots of `/`, and never were.
- **`home`** — `TIMELINE_CREATE="yes"`. This is the one that matters: hourly timeline
  snapshots of `/home`, running since install, kept in the nested `@home/.snapshots`
  (needs no fstab entry — a nested subvolume is visible inside its parent's mount).
  **`snapper-timeline.timer` is load-bearing** — the only thing snapshotting `~`, where
  everything irreplaceable lives.

  Retention is `HOURLY=5`, `DAILY=7`, `WEEKLY=4`, `MONTHLY=4` — 20 snapshots, about four
  months (it was one week until 2026-09-04, short enough that a mistake noticed after a
  trip was already unrecoverable). `NUMBER_CLEANUP="no"`, so `NUMBER_LIMIT=50` is inert;
  only the timeline algorithm prunes this config.

  Snapshots are **not backups** — same filesystem as the data, so a failed disk or
  anything running as root takes them along with the originals. Protection against
  mistakes, not loss; an attacker with root deletes them in one command. Only an
  off-machine copy changes that, and there still isn't one.

`snapper-cleanup.timer` enforces retention for both.

**Checking `/home/.snapshots` as a normal user shows an empty directory** — it's
`root:users` and this user isn't in `users`, so `ls` prints nothing and looks empty
rather than unreadable if stderr is discarded. That misread nearly got
`snapper-timeline.timer` disabled as "600 runs, zero snapshots" on 2026-09-03. Use
`sudo snapper -c home list`.

Before "tidying" anything here:

- A **mounted subvolume can't be `rm -rf`'d** — it returns `EBUSY`. Removing one means
  editing fstab first, then `umount`, then `btrfs subvolume delete` from a `subvolid=5`
  mount. Deleting the subvolume while its fstab line remains is a **boot failure**.
- An empty subvolume costs metadata only (~16 KiB); subvolumes share the pool, so
  `df`/`findmnt` against one reports the whole filesystem — never a reason to remove one.
