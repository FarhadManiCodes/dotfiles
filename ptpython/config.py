"""
Configuration for ptpython with OneDark (default) and PaperColor Light themes.
Toggle between themes with Ctrl+T, Ctrl+T
Copy this file to $XDG_CONFIG_HOME/ptpython/config.py
"""

import atexit
import sys

from prompt_toolkit.styles import Style
from ptpython.layout import CompletionVisualisation

__all__ = ["configure"]


# The starting theme follows foot's state file.
def _detect_foot_theme():
    from pathlib import Path

    state_file = Path.home() / ".local/state/foot_theme_state"
    try:
        # A corrupt file is not "light", so it gives the default theme.
        text = state_file.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return "onedark"
    return "papercolor" if text.strip() == "light" else "onedark"


# Each theme is a palette; _UI_STYLE names its colors. Every One Dark color
# maps to one PaperColor color; the two dark grays share one light gray.
# One Dark: https://github.com/joshdick/onedark.vim
# PaperColor: https://github.com/NLKNguyen/papercolor-theme
_THEMES = {
    "onedark": {
        "code": "monokai",
        "message": "🌙 Switched to OneDark theme",
        "colors": {
            "bg": "#282c34",
            "bg1": "#2c323c",  # Toolbars, menus, current line
            "bg2": "#3e4452",  # Selection
            "fg": "#abb2bf",
            "gray": "#5c6370",
            "gray2": "#636d83",  # Line numbers
            "blue": "#61afef",
            "green": "#98c379",
            "purple": "#c678dd",
            "orange": "#d19a66",
            "red": "#e06c75",
            "yellow": "#e5c07b",
        },
    },
    "papercolor": {
        "code": "default",
        "message": "🌞 Switched to PaperColor Light theme",
        "colors": {
            "bg": "#eeeeee",
            "bg1": "#d0d0d0",
            "bg2": "#bcbcbc",
            "fg": "#444444",
            "gray": "#878787",
            "gray2": "#878787",
            "blue": "#0087af",
            "green": "#008700",
            "purple": "#8700af",
            "orange": "#d75f00",
            "red": "#af0000",
            "yellow": "#5f8700",
        },
    },
}

# A key that restates a color it already inherits, from "" or from the key
# before its last dot, leaves that color out.
_UI_STYLE = {
    "": "{fg} bg:{bg}",
    "prompt": "{blue} bold",
    "out": "{fg}",
    "status-toolbar": "{fg} bg:{bg1}",
    "status-toolbar.key": "{blue} bg:{bg1} bold",
    "status-toolbar.title": "{yellow} bold",
    "status-toolbar.input-mode": "{orange} bold",
    "bottom-toolbar": "bg:{bg1}",
    "line-number": "{gray2}",
    "line-number.current": "{fg} bg:{bg1} bold",
    "cursor-line": "bg:{bg1}",
    "selected": "bg:{bg2}",
    "search": "{bg} bg:{yellow}",
    "search.current": "bg:{orange} bold",
    "matching-bracket": "{bg} bg:{purple}",
    "matching-bracket.other": "{purple} bg:{bg}",
    "matching-bracket.cursor": "{bg} bg:{red}",
    "completion-menu": "{fg} bg:{bg1}",
    "completion-menu.completion": "",
    "completion-menu.completion.current": "{bg} bg:{blue}",
    "completion-menu.meta.completion": "{gray} bg:{bg1}",
    "completion-menu.meta.completion.current": "{bg} bg:{blue}",
    "completion-menu.multi-column-meta": "{gray} bg:{bg1}",
    "scrollbar": "bg:{gray}",
    "scrollbar.background": "bg:{bg1}",
    "scrollbar.button": "bg:{blue}",
    "scrollbar.arrow": "{fg} bg:{gray}",
    "validation-toolbar": "{red} bg:{bg1}",
    "system-toolbar": "{green} bg:{bg1}",
    "signature-toolbar": "{yellow} bg:{bg}",
    "auto-suggestion": "{gray}",
    "docstring": "{gray} italic",
    "menu": "{fg} bg:{bg1}",
    "menu.border": "{gray}",
    "dialog": "bg:{bg1}",
    "tab": "{fg} bg:{bg1}",  # Tab characters in the input
    "separator": "{gray}",
    "frame.border": "{gray}",
}


def _ui_style(theme):
    """Fill _UI_STYLE with the theme's colors."""
    colors = _THEMES[theme]["colors"]
    return {key: value.format(**colors) for key, value in _UI_STYLE.items()}


def _set_terminal_colors(theme):
    """Set terminal background and foreground to the theme's colors."""
    colors = _THEMES[theme]["colors"]
    sys.stdout.write(f"\033]11;{colors['bg']}\007")  # Background
    sys.stdout.write(f"\033]10;{colors['fg']}\007")  # Foreground
    sys.stdout.flush()


def reset_terminal_colors():
    """Reset terminal colors to default."""
    sys.stdout.write("\033]111\007")  # Reset background
    sys.stdout.write("\033]110\007")  # Reset foreground
    sys.stdout.flush()


def _apply_theme(repl, theme):
    """Use the theme's UI and code schemes and terminal colors."""
    repl.use_ui_colorscheme(theme)
    repl.use_code_colorscheme(_THEMES[theme]["code"])
    _set_terminal_colors(theme)


def toggle_theme(repl, theme):
    """Switch from `theme` to the other one; return the new theme."""
    theme = "papercolor" if theme == "onedark" else "onedark"
    _apply_theme(repl, theme)
    print(_THEMES[theme]["message"])
    return theme


def configure(repl):
    """
    Configuration method. This is called during the start-up of ptpython.

    :param repl: `PythonRepl` instance.
    """
    theme = _detect_foot_theme()

    # Register reset function to be called on exit
    atexit.register(reset_terminal_colors)

    # Show function signature (bool).
    repl.show_signature = True

    # Show docstring (bool).
    repl.show_docstring = False

    # Show the "[Meta+Enter] Execute" message when pressing [Enter] only
    # inserts a newline instead of executing the code.
    repl.show_meta_enter_message = True

    # Show completions. (NONE, POP_UP, MULTI_COLUMN or TOOLBAR)
    repl.completion_visualisation = CompletionVisualisation.POP_UP

    # When CompletionVisualisation.POP_UP has been chosen, use this
    # scroll_offset in the completion menu.
    repl.completion_menu_scroll_offset = 0

    # Show line numbers (when the input contains multiple lines.)
    repl.show_line_numbers = True

    # Show status bar.
    repl.show_status_bar = True

    # When the sidebar is visible, also show the help text.
    repl.show_sidebar_help = True

    # Swap light/dark colors on or off
    repl.swap_light_and_dark = False

    # Highlight matching parentheses.
    repl.highlight_matching_parenthesis = True

    # Line wrapping. (Instead of horizontal scrolling.)
    repl.wrap_lines = True

    # Mouse support.
    repl.enable_mouse_support = True

    # Complete while typing. (Don't require tab before the
    # completion menu is shown.)
    repl.complete_while_typing = True

    # Fuzzy and dictionary completion.
    repl.enable_fuzzy_completion = False
    repl.enable_dictionary_completion = False

    # Vi mode.
    repl.vi_mode = True

    # Enable the modal cursor (when using Vi mode).
    repl.cursor_shape_config = "Modal (vi)"

    # Paste mode. (When True, don't insert whitespace after new line.)
    repl.paste_mode = False

    # Use the classic prompt. (Display '>>>' instead of 'In [1]'.)
    repl.prompt_style = "classic"  # 'classic' or 'ipython'

    # Don't insert a blank line after the output.
    repl.insert_blank_line_after_output = False

    # History Search.
    repl.enable_history_search = False

    # Enable auto suggestions.
    repl.enable_auto_suggest = False

    # Enable open-in-editor. Pressing C-x C-e in emacs mode or 'v' in
    # Vi navigation mode will open the input in the current editor.
    repl.enable_open_in_editor = True

    # Enable system prompt. Pressing meta-! will display the system prompt.
    # Also enables Control-Z suspend.
    repl.enable_system_bindings = True

    # Ask for confirmation on exit.
    repl.confirm_exit = True

    # Enable input validation.
    repl.enable_input_validation = True

    # Set color depth to true color for best experience
    repl.color_depth = "DEPTH_24_BIT"  # True color.

    # Min/max brightness
    repl.min_brightness = 0.0
    repl.max_brightness = 1.0

    # Syntax highlighting
    repl.enable_syntax_highlighting = True

    # Get into Vi navigation mode at startup
    repl.vi_start_in_navigation_mode = False

    # Preserve last used Vi input mode between main loop iterations
    repl.vi_keep_last_used_mode = False

    # Install both themes and use the one foot is in
    for name in _THEMES:
        repl.install_ui_colorscheme(name, Style.from_dict(_ui_style(name)))
    _apply_theme(repl, theme)

    # Add theme toggle keybinding: Ctrl+T, Ctrl+T
    @repl.add_key_binding("c-t", "c-t")
    def _(event):
        """Toggle between OneDark and PaperColor themes"""
        nonlocal theme
        theme = toggle_theme(repl, theme)
