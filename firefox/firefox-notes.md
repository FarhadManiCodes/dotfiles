# Firefox Setup Notes

## Known Tradeoffs

### Video Calls / Screen Sharing
If a video call (Google Meet, Jitsi, Discord, etc.) doesn't work or has poor quality:
```
# about:config — set both to false temporarily
media.peerconnection.ice.no_host = false
media.peerconnection.ice.default_address_only = false
```
Set back to `true` after the call.

### Strict Tracking Protection
If a site looks broken (missing content, broken layout):
- Click the shield icon in the address bar
- Toggle protection off for that site only
- uBlock Origin may also be the cause — try disabling it per-site

---

## Pending To-Do

- **Tridactyl blacklist** — add sensitive sites to `tridactylrc`:
  ```
  blacklistadd https://your-bank.com
  blacklistadd https://your-password-manager.com
  ```
- **Tridactyl deep config session** — `tridactylrc` bindings, search engines review, quality of life tweaks (scheduled for a future session)
- **Firefox Multi-Account Containers** — consider installing for site isolation (banking, email, social in separate containers)

---

## Key Settings Reference

### about:config changes
| Preference | Value | Reason |
|---|---|---|
| `browser.urlbar.suggest.searches` | false | Stop sending keystrokes to Google |
| `browser.ml.chat.enabled` | false | Disable AI chatbot nudges |
| `browser.tabs.extraDragSpace` | false | Remove wasted space |
| `browser.compactmode.show` | true | Unlock compact density |
| `toolkit.legacyUserProfileCustomizations.stylesheets` | true | Enable userChrome.css |
| `dom.ipc.processCount` | 12 | More process isolation |
| `media.peerconnection.ice.no_host` | true | WebRTC hardening* |
| `media.peerconnection.ice.default_address_only` | true | WebRTC hardening* |
| `network.dns.disablePrefetch` | true | Privacy |
| `network.prefetch-next` | false | Privacy |
| `network.http.speculative-parallel-limit` | 0 | Privacy |
| `dom.screenwakelock.enabled` | false | Prevent Firefox from requesting suspend inhibition via xdg-portal — swayidle timers are the sole authority for suspend |

*May affect video calls — see above

### userChrome.css location
Managed via dotfiles — edit at `dotfiles/firefox/userChrome.css`.
`install.sh` symlinks it into the correct profile directory automatically.
Restart Firefox after changes.

---

## Extensions

| Extension | Status | Notes |
|---|---|---|
| Tridactyl | Active | Config at `~/dotfiles/tridactyl/tridactylrc` |
| uBlock Origin | Active | Strict mode + annoyances + DE/FA/IT lists |
| Proton VPN | Active | Browser-only, not system-wide. NetShield not available in extension |
| DownThemAll | Active | Default settings, configure if issues arise |
| Zotero Connector | Disabled | Enable manually when needed |

---

## Proton VPN Notes
- Browser extension only — CLI and system traffic bypasses VPN
- NetShield only available on mobile app and desktop app (not browser extension)
- WebRTC leak protection in extension is redundant with `about:config` settings — either is fine
- No system-wide VPN needed for current use case

---

## uBlock Origin Filter Lists
Active lists beyond defaults:
- Cookie notices: EasyList/uBO + AdGuard/uBO (4/4)
- Annoyances: EasyList + AdGuard + uBlock filters (10/10)
- Regions: EasyList Germany, PersianBlocker, EasyList Italy
