" Lightline
let g:lightline = {
  \ 'colorscheme': 'onedark',
  \ 'active': {
  \   'left': [['mode', 'paste'], ['readonly', 'filename', 'modified']],
  \   'right': [['lineinfo'], ['percent'], ['ale']]
  \ },
  \ 'component_function': {
  \   'ale': 'ALEStatus'
  \ }
\}

function! ALEStatus() abort
  let l:counts = ale#statusline#Count(bufnr(''))
  let l:all_errors = l:counts.error + l:counts.style_error
  let l:all_warnings = l:counts.warning + l:counts.style_warning
  return l:all_errors == 0 && l:all_warnings == 0 ? '✔' :
      \ printf('E:%d W:%d', all_errors, all_warnings)
endfunction

" ALE Configuration
let g:ale_enabled = 1
let g:ale_lint_on_enter = 1
let g:ale_lint_on_save = 1
let g:ale_fix_on_save = 1
let g:ale_lint_on_text_changed = 'never'
let g:ale_lint_on_insert_leave = 0
let g:ale_sign_error = '✘'
let g:ale_sign_warning = '⚠'
highlight ALEErrorSign ctermbg=NONE ctermfg=red
highlight ALEWarningSign ctermbg=NONE ctermfg=yellow

" Linters & Fixers
let g:ale_linters = {
\   'python': ['flake8', 'mypy', 'pylint'],
\   'yaml': ['yamllint'],
\   'json': ['jsonlint'],
\   'sh': ['shellcheck'],
\}

let g:ale_fixers = {
\   'python': ['black', 'isort'],
\   'sql': ['sqlfmt'],
\   'json': ['jq'],
\   'yaml': ['yamlfix'],
\   'sh': ['shfmt'],
\ '*': ['remove_trailing_lines', 'trim_whitespace'],
\}

" ShellCheck-specific settings
" ShellCheck-specific settings (preferred)
let g:ale_sh_shellcheck_options = '-x -e SC1091 --shell=bash --source-path=SCRIPTDIR:' . expand('$XDG_CONFIG_HOME') . ':' . expand('$HOME') . '/.config'
let g:ale_sh_shfmt_options = '-i 2 -ci'
" YouCompleteMe
let g:ycm_autoclose_preview_window_after_completion = 1
let g:ycm_autoclose_preview_window_after_insertion = 1
let g:ycm_show_diagnostics_ui = 0
let g:ycm_enable_diagnostic_signs = 0
let g:ycm_echo_current_diagnostic = 0
let g:ycm_max_diagnostics_to_display = 0
let g:ycm_enable_diagnostic_highlighting = 0
let g:ycm_python_interpreter_path = 'python3'
let g:ycm_filetype_whitelist = {
  \ 'python': 1,
  \ 'cpp': 1,
  \ 'c': 1,
  \ 'h': 1,
  \ 'sql': 1,
  \ 'yaml': 1,
  \ 'sh': 1
\ }

" Undotree
let g:undotree_WindowLayout = 3

" Dadbod (SQL)
let g:db_ui_use_nerd_fonts = 1
