# SSH — passphrase-protected key, agent with a lifetime

One ED25519 key (`~/.ssh/id_ed25519`), used only for GitHub, **passphrase-protected**
(`cipher: aes256-ctr`, `kdf: bcrypt`). Adding the passphrase didn't change the public key,
so nothing had to be re-uploaded anywhere.

Be precise about what that buys:

- **Protects against** malware that reads the key file and exfiltrates it for use
  elsewhere later — the common, low-effort attack.
- **Does not protect against** an attacker active on this machine while the agent holds
  the key — they can sign via `$SSH_AUTH_SOCK`. But they can't copy a *usable* key off
  the box, a real reduction in what a compromise is worth.

`ssh/config` sets `AddKeysToAgent 1h` — a **lifetime, not `yes`**. `yes` keeps the key
resident until logout; the hour bounds the window a compromised process could use the
agent. The agent is Arch's socket-activated user unit, which does nothing unless
`SSH_AUTH_SOCK` points at it, hence the entry in `environment.d/defaults.conf`.
`install.sh` symlinks the config, forces `~/.ssh` to 0700, and enables `ssh-agent.socket`.

It also sets `ServerAliveInterval 20` / `ServerAliveCountMax 3` — an otherwise idle,
unresponsive server gets probed every 20s and dropped after ~60s of silence. This detects
a dead connection; it doesn't reconnect or resume an interrupted Git operation. Connection
setup keeps the system-default timeout.

**Do not test key encryption with `grep ENCRYPTED`.** That string only appears in *old
PEM* keys (`Proc-Type: 4,ENCRYPTED`); modern `-----BEGIN OPENSSH PRIVATE KEY-----` files
are base64 with the cipher recorded *inside* the blob, so the grep falsely reports
"unencrypted" for a protected key — it did exactly that on 2026-09-02. Use:

```bash
ssh-keygen -y -f ~/.ssh/id_ed25519 -P ''    # non-zero exit => protected
```

`ssh/known_hosts` is deliberately **not** tracked — it churns, and pinning GitHub's host
key in the repo buys little over trust-on-first-use for a single well-known host.
