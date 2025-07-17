"""
Configuration for ptpython with OneDark (default) and PaperColor Light themes.
Toggle between themes with Ctrl+T, Ctrl+T
Copy this file to $XDG_CONFIG_HOME/ptpython/config.py
"""

import sys
import atexit
from prompt_toolkit.filters import ViInsertMode
from prompt_toolkit.key_binding.key_processor import KeyPress
from prompt_toolkit.keys import Keys
from prompt_toolkit.styles import Style

from ptpython.layout import CompletionVisualisation

__all__ = ["configure"]

# Global theme state
current_theme = "onedark"  # Default theme


def set_onedark_terminal():
    """Set terminal background and foreground to OneDark colors."""
    sys.stdout.write('\033]11;#282c34\007')  # Background
    sys.stdout.write('\033]10;#abb2bf\007')  # Foreground
    sys.stdout.flush()


def set_papercolor_terminal():
    """Set terminal background and foreground to PaperColor Light colors."""
    sys.stdout.write('\033]11;#eeeeee\007')  # Background  
    sys.stdout.write('\033]10;#444444\007')  # Foreground
    sys.stdout.flush()


def reset_terminal_colors():
    """Reset terminal colors to default."""
    sys.stdout.write('\033]111\007')  # Reset background
    sys.stdout.write('\033]110\007')  # Reset foreground
    sys.stdout.flush()


def toggle_theme(repl):
    """Toggle between OneDark and PaperColor themes."""
    global current_theme
    
    if current_theme == "onedark":
        current_theme = "papercolor"
        repl.use_ui_colorscheme("papercolor")
        repl.use_code_colorscheme("default")  # Light scheme for syntax
        set_papercolor_terminal()
        print("🌞 Switched to PaperColor Light theme")
    else:
        current_theme = "onedark"
        repl.use_ui_colorscheme("onedark")
        repl.use_code_colorscheme("monokai")  # Dark scheme for syntax
        set_onedark_terminal()
        print("🌙 Switched to OneDark theme")


def configure(repl):
    """
    Configuration method. This is called during the start-up of ptpython.

    :param repl: `PythonRepl` instance.
    """
    global current_theme
    
    # Set OneDark as default theme on startup
    set_onedark_terminal()
    
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

    # Install both custom colorschemes
    repl.install_ui_colorscheme("onedark", Style.from_dict(_onedark_ui_colorscheme))
    repl.install_ui_colorscheme("papercolor", Style.from_dict(_papercolor_ui_colorscheme))
    
    # Set default theme
    if current_theme == "onedark":
        repl.use_ui_colorscheme("onedark")
        repl.use_code_colorscheme("monokai")
    else:
        repl.use_ui_colorscheme("papercolor")
        repl.use_code_colorscheme("default")

    # Add theme toggle keybinding: Ctrl+T, Ctrl+T
    @repl.add_key_binding("c-t", "c-t")
    def _(event):
        """Toggle between OneDark and PaperColor themes"""
        toggle_theme(repl)


# OneDark UI colorscheme
# Based on the official OneDark theme: https://github.com/joshdick/onedark.vim
_onedark_ui_colorscheme = {
    # Base colors
    '': '#abb2bf bg:#282c34',  # Default foreground and background
    
    # Prompt and input
    'prompt': '#61afef bg:#282c34 bold',  # Blue prompt
    'continuation': '#61afef bg:#282c34',  # Continuation prompt
    'default': '#abb2bf bg:#282c34',  # Default text
    
    # Output and errors
    'out': '#abb2bf bg:#282c34',  # Normal output
    'error': '#e06c75 bg:#282c34',  # Error messages (red)
    
    # Status and toolbars
    'status-toolbar': '#abb2bf bg:#2c313c',  # Status bar
    'status-toolbar.key': '#61afef bg:#2c313c bold',  # Key hints in status
    'status-toolbar.title': '#e5c07b bg:#2c313c bold',  # Title in status
    'bottom-toolbar': '#abb2bf bg:#2c313c',  # Bottom toolbar
    'bottom-toolbar.key': '#61afef bg:#2c313c bold',  # Keys in bottom toolbar
    'bottom-toolbar.title': '#e5c07b bg:#2c313c bold',  # Title in bottom toolbar
    
    # Line numbers and cursor
    'line-number': '#636d83 bg:#282c34',  # Line numbers
    'line-number.current': '#abb2bf bg:#2c313c bold',  # Current line number
    'cursor-line': 'bg:#2c313c',  # Current line highlight
    
    # Selection and search
    'selected': '#abb2bf bg:#3e4451',  # Selected text
    'search': '#282c34 bg:#e5c07b',  # Search highlight
    'search.current': '#282c34 bg:#d19a66 bold',  # Current search match
    'incremental-search': '#282c34 bg:#98c379',  # Incremental search
    
    # Brackets and matching
    'matching-bracket': '#282c34 bg:#c678dd',  # Matching brackets
    'matching-bracket.other': '#c678dd bg:#282c34',  # Other matching bracket
    'matching-bracket.cursor': '#282c34 bg:#e06c75',  # Bracket at cursor
    
    # Completion menu
    'completion-menu': '#abb2bf bg:#2c313c',  # Completion popup background
    'completion-menu.completion': '#abb2bf bg:#2c313c',  # Individual completions
    'completion-menu.completion.current': '#282c34 bg:#61afef',  # Selected completion
    'completion-menu.meta.completion': '#5c6370 bg:#2c313c',  # Completion metadata
    'completion-menu.meta.completion.current': '#282c34 bg:#61afef',  # Selected meta
    'completion-menu.multi-column-meta': '#5c6370 bg:#2c313c',  # Multi-column meta
    'completion-menu.progressbar': 'bg:#61afef',  # Progress bar in completion
    'completion-menu.progressbar.used': 'bg:#98c379',  # Used portion of progress bar
    
    # Scrollbars
    'scrollbar': 'bg:#5c6370',  # Scrollbar track
    'scrollbar.background': 'bg:#2c313c',  # Scrollbar background
    'scrollbar.button': 'bg:#61afef',  # Scrollbar buttons
    'scrollbar.arrow': '#abb2bf bg:#5c6370',  # Scrollbar arrows
    
    # Validation and syntax errors
    'validation-toolbar': '#e06c75 bg:#2c313c',  # Validation error toolbar
    'validation-toolbar.title': '#e06c75 bg:#2c313c bold',  # Validation title
    
    # System/shell integration
    'system-toolbar': '#98c379 bg:#2c313c',  # System command toolbar
    
    # Auto-suggestion
    'auto-suggestion': '#5c6370 bg:#282c34',  # Auto-suggestions (dim)
    
    # Vi mode indicators
    'vi-mode': '#d19a66 bg:#2c313c bold',  # Vi mode indicator
    
    # Python-specific elements
    'docstring': '#5c6370 bg:#282c34 italic',  # Docstrings
    'signature': '#e5c07b bg:#282c34',  # Function signatures
    
    # Menu and dialog
    'menu': '#abb2bf bg:#2c313c',  # General menu
    'menu.border': '#5c6370',  # Menu borders
    'dialog': '#abb2bf bg:#2c313c',  # Dialog background
    'dialog.border': '#5c6370',  # Dialog borders
    'dialog.title': '#61afef bg:#2c313c bold',  # Dialog titles
    
    # Tabs (if used)
    'tab': '#abb2bf bg:#2c313c',  # Tab background
    'tab.active': '#282c34 bg:#61afef bold',  # Active tab
    
    # Misc elements
    'separator': '#5c6370',  # Separators and borders
    'frame.border': '#5c6370',  # Frame borders
    'frame.title': '#e5c07b bg:#282c34 bold',  # Frame titles
}


# PaperColor Light UI colorscheme
# Based on the official PaperColor theme: https://github.com/NLKNguyen/papercolor-theme
_papercolor_ui_colorscheme = {
    # Base colors
    '': '#444444 bg:#eeeeee',  # Default foreground and background
    
    # Prompt and input
    'prompt': '#0087af bg:#eeeeee bold',  # Blue prompt
    'continuation': '#0087af bg:#eeeeee',  # Continuation prompt
    'default': '#444444 bg:#eeeeee',  # Default text
    
    # Output and errors
    'out': '#444444 bg:#eeeeee',  # Normal output
    'error': '#af0000 bg:#eeeeee',  # Error messages (red)
    
    # Status and toolbars
    'status-toolbar': '#444444 bg:#d0d0d0',  # Status bar
    'status-toolbar.key': '#0087af bg:#d0d0d0 bold',  # Key hints in status
    'status-toolbar.title': '#5f8700 bg:#d0d0d0 bold',  # Title in status
    'bottom-toolbar': '#444444 bg:#d0d0d0',  # Bottom toolbar
    'bottom-toolbar.key': '#0087af bg:#d0d0d0 bold',  # Keys in bottom toolbar
    'bottom-toolbar.title': '#5f8700 bg:#d0d0d0 bold',  # Title in bottom toolbar
    
    # Line numbers and cursor
    'line-number': '#878787 bg:#eeeeee',  # Line numbers
    'line-number.current': '#444444 bg:#d0d0d0 bold',  # Current line number
    'cursor-line': 'bg:#d0d0d0',  # Current line highlight
    
    # Selection and search
    'selected': '#444444 bg:#bcbcbc',  # Selected text
    'search': '#eeeeee bg:#5f8700',  # Search highlight
    'search.current': '#eeeeee bg:#d75f00 bold',  # Current search match
    'incremental-search': '#eeeeee bg:#008700',  # Incremental search
    
    # Brackets and matching
    'matching-bracket': '#eeeeee bg:#8700af',  # Matching brackets
    'matching-bracket.other': '#8700af bg:#eeeeee',  # Other matching bracket
    'matching-bracket.cursor': '#eeeeee bg:#af0000',  # Bracket at cursor
    
    # Completion menu
    'completion-menu': '#444444 bg:#d0d0d0',  # Completion popup background
    'completion-menu.completion': '#444444 bg:#d0d0d0',  # Individual completions
    'completion-menu.completion.current': '#eeeeee bg:#0087af',  # Selected completion
    'completion-menu.meta.completion': '#878787 bg:#d0d0d0',  # Completion metadata
    'completion-menu.meta.completion.current': '#eeeeee bg:#0087af',  # Selected meta
    'completion-menu.multi-column-meta': '#878787 bg:#d0d0d0',  # Multi-column meta
    'completion-menu.progressbar': 'bg:#0087af',  # Progress bar in completion
    'completion-menu.progressbar.used': 'bg:#008700',  # Used portion of progress bar
    
    # Scrollbars
    'scrollbar': 'bg:#878787',  # Scrollbar track
    'scrollbar.background': 'bg:#d0d0d0',  # Scrollbar background
    'scrollbar.button': 'bg:#0087af',  # Scrollbar buttons
    'scrollbar.arrow': '#444444 bg:#878787',  # Scrollbar arrows
    
    # Validation and syntax errors
    'validation-toolbar': '#af0000 bg:#d0d0d0',  # Validation error toolbar
    'validation-toolbar.title': '#af0000 bg:#d0d0d0 bold',  # Validation title
    
    # System/shell integration
    'system-toolbar': '#008700 bg:#d0d0d0',  # System command toolbar
    
    # Auto-suggestion
    'auto-suggestion': '#878787 bg:#eeeeee',  # Auto-suggestions (dim)
    
    # Vi mode indicators
    'vi-mode': '#d75f00 bg:#d0d0d0 bold',  # Vi mode indicator
    
    # Python-specific elements
    'docstring': '#878787 bg:#eeeeee italic',  # Docstrings
    'signature': '#5f8700 bg:#eeeeee',  # Function signatures
    
    # Menu and dialog
    'menu': '#444444 bg:#d0d0d0',  # General menu
    'menu.border': '#878787',  # Menu borders
    'dialog': '#444444 bg:#d0d0d0',  # Dialog background
    'dialog.border': '#878787',  # Dialog borders
    'dialog.title': '#0087af bg:#d0d0d0 bold',  # Dialog titles
    
    # Tabs (if used)
    'tab': '#444444 bg:#d0d0d0',  # Tab background
    'tab.active': '#eeeeee bg:#0087af bold',  # Active tab
    
    # Misc elements
    'separator': '#878787',  # Separators and borders
    'frame.border': '#878787',  # Frame borders
    'frame.title': '#5f8700 bg:#eeeeee bold',  # Frame titles
}
