from pathlib import Path

state_file = Path.home() / ".local/state/foot_theme_state"
try:
    mode = state_file.read_text().strip()
except Exception:
    mode = 'dark'

ip = get_ipython()
if mode == 'light':
    ip.colors = 'LightBG'
    ip.highlighting_style = 'pastie'
else:
    ip.colors = 'Linux'
    ip.highlighting_style = 'one-dark'
