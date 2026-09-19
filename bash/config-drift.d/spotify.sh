# shellcheck shell=bash
# install.sh seeds this copy once (docs/architecture/config-drift.md). Never
# print values or parser errors, which can include file contents.
check_spotify_config() {
  hdr "Spotify config matches the template"
  if spotify_report=$(python3 - "$df_dir/spotify-player/app.toml" \
      "${XDG_CONFIG_HOME:-$HOME/.config}/spotify-player/app.toml" 2>/dev/null <<'PY'
import json
import pprint
import sys

try:
    import tomllib
except ImportError:
    print("not compared: Python 3.11+ with tomllib is required")
    sys.exit(2)

configs = []
for label, path in zip(("template", "live config"), sys.argv[1:]):
    try:
        with open(path, "rb") as source:
            config = tomllib.load(source)
    except (OSError, ValueError):
        print(f"not compared: {label} is missing, unreadable, or invalid TOML")
        sys.exit(2)
    config.pop("client_id", None)
    configs.append(config)

template, live = configs
for key in sorted(template.keys() | live.keys()):
    # A changed nested value is reported under its top-level table name.
    name = json.dumps(key, ensure_ascii=True)
    if key not in live:
        print(f"missing from live config: {name}")
    elif key not in template:
        print(f"only in live config: {name}")
    # Standard-library representations preserve types, including true vs 1.
    # Sorting nested dictionaries makes TOML key order irrelevant.
    elif pprint.pformat(template[key], sort_dicts=True) != pprint.pformat(live[key], sort_dicts=True):
        print(f"different setting: {name}")
PY
  ); then
    if [[ -n $spotify_report ]]; then
      warn "spotify-player/app.toml differs — review settings; preserve the local client_id"
      printf '%s\n' "$spotify_report" | sed 's/^/       /'
    else
      ok "all settings match (top-level client_id excluded)"
    fi
  else
    warn "spotify-player/app.toml: ${spotify_report:-not compared: Python check failed}"
  fi
}
