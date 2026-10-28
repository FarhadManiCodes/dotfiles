c.InteractiveShellApp.extensions = ["autoreload"]
# The session's imports, one entry each: IPython runs each on its own, so a
# venv without numpy still gets the rest.
c.InteractiveShellApp.exec_lines = [
    "%autoreload 2",
    "import numpy as np",
    "import polars as pl",
    "from pathlib import Path",
]

c.InteractiveShell.editor = "nvim"
c.InteractiveShell.confirm_exit = False
c.InteractiveShell.xmode = "Verbose"
