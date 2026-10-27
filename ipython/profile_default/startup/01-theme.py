from pathlib import Path

state_file = Path.home() / ".local/state/foot_theme_state"
try:
    # A corrupt file is not "light", so it gives the default theme.
    mode = state_file.read_text(encoding="utf-8", errors="replace").strip()
except OSError:
    mode = "dark"

ip = get_ipython()
if mode == "light":
    ip.colors = "LightBG"
    ip.highlighting_style = "pastie"
else:
    ip.colors = "Linux"
    ip.highlighting_style = "one-dark"
