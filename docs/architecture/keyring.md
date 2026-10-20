# GNOME Keyring

## Packages and startup

`gnome-keyring` provides `org.freedesktop.secrets`; `libsecret` supplies
`secret-tool`. Optional `seahorse` (Passwords and Keys) manages entries and
keyring passwords. No GNOME session or Qt5 is required.

The packaged `gnome-keyring-daemon.socket` is enabled, including by the explicit
list in `install.sh`. D-Bus activation is also provided by the package. Niri
imports its Wayland environment into the user manager. No extra Niri startup
command, custom daemon unit or shell exports are needed.

Unlocking is manual. `/etc/pam.d/ly` has no `pam_gnome_keyring.so` hooks; preserve
that accepted login configuration.

## Locking policy

- Unlock through Seahorse or the prompt raised by an application needing a secret.
- Lock manually with `keyring-lock`, or lock an individual keyring in Seahorse.
- Ctrl+Alt+L, the power menu's Lock action, the five-minute desktop idle timeout,
  and swayidle's before-sleep action all reach `bash/lock-once`.
- `lock-once` acquires the screen lock first, then invokes `keyring-lock`.
  It also invokes the helper if the screen is already locked or screen locking
  fails. Repeated suspend attempts still avoid duplicate swaylock instances.
- No independent keyring timer is configured. Screen unlock does not unlock
  the keyrings. Running `swaylock` directly bypasses this integration.

`bash/keyring-lock` uses GNOME's `org.freedesktop.Secret.Service.LockService`
extension. It locks **all persistent keyrings and clears temporary session
secrets**. It checks whether the provider is running first, so locking does not
start an absent provider. Both D-Bus calls have two-second deadlines. Failures
are reported to stderr, the journal (`keyring-lock` tag) and a critical
notification, without preventing screen locking. `install.sh`'s existing
`bash/*` mapping installs it as `~/.local/bin/keyring-lock`.

GNOME Keyring provides no per-read approval or read notification. Once unlocked,
same-user programs can query it. Locking cannot revoke secrets already retrieved
by applications. This policy is not isolation from same-user coding agents.

## Store and retrieve

Run interactively; the terminal prompt hides the API key:

```sh
secret-tool store --label='Voyage AI API key' service voyage
```

The terminal prompt takes the API key; a separate graphical prompt takes the
keyring password. Labels and lookup attributes are metadata, not places for
secrets. Browser copies may enter clipboard history; clearing the clipboard
does not remove history entries.

Applications capture `secret-tool lookup service voyage` at launch. Bare lookup
prints the secret, as can `secret-tool search`; never run them unredirected
while sharing a terminal. App-specific retrieval is managed separately.

## Recovery and maintenance

Keyrings live under `${XDG_DATA_HOME:-$HOME/.local/share}/keyrings/`. Never commit
their contents or keyring passwords. Preserve the keyring password independently;
Seahorse requires the existing password to change it without replacing the store.

Include this directory in a future protected off-machine backup. The broader
backup task remains deferred in `TODO.md`; this change does not set up a backup.
Prefer a locked copy. A copy on the same disk cannot protect against disk loss.
API keys can instead be revoked and recreated through their providers if needed.

Metadata-only checks:

```sh
systemctl --user is-enabled gnome-keyring-daemon.socket
busctl --user status org.freedesktop.secrets
busctl --user get-property org.freedesktop.secrets \
    /org/freedesktop/secrets/aliases/default \
    org.freedesktop.Secret.Collection Locked
journalctl -t keyring-lock
```

The locking extension is GNOME-specific; changing providers requires revisiting
this helper. Upstream implementation:
<https://github.com/GNOME/gnome-keyring/blob/master/daemon/dbus/gkd-secret-service.c>
and <https://github.com/GNOME/gnome-keyring/blob/master/daemon/dbus/gkd-secret-lock.c>.

## Rollout checks (2026-10-20)

Shell syntax and ShellCheck passed for the lock helpers; installer syntax, Niri
validation against the live symlink target, and user-unit verification passed.
The installed manual helper returned successfully; a subsequent metadata query
reported the default keyring `Locked=true`. The daemon socket was enabled and
swayidle active. `config-drift` outside the filesystem sandbox reported zero
items needing attention and three access exclusions. Its sandboxed run mapped
root-owned files to `nobody` and blocked unit verification; that report was not
treated as evidence of changed host ownership.

No test suites were added or run. Actual shortcut, idle, suspend/resume and fresh
login cycles remain unexercised. On the next normal screen-lock cycle, unlock the
screen and confirm that accessing the keyring prompts again. No secrets were read
by the setup checks.
