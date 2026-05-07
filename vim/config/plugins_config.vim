" Lightline
let g:lightline = {
  \ 'colorscheme': 'one',
  \ 'active': {
  \   'left': [['mode', 'paste'], ['readonly', 'filename', 'modified']],
  \   'right': [['lineinfo'], ['percent'], ['virtualenv']]
  \ },
  \ 'component_function': {
  \   'virtualenv': 'VirtualEnvStatus'
  \ }
\}

function! VirtualEnvStatus() abort
  " Check for various virtual environment indicators
  if exists('$VIRTUAL_ENV')
    return fnamemodify($VIRTUAL_ENV, ':t')
  elseif exists('$CONDA_DEFAULT_ENV')
    return $CONDA_DEFAULT_ENV
  elseif exists('$PIPENV_ACTIVE') && $PIPENV_ACTIVE == '1'
    " Try to get pipenv project name
    let pipenv_project = system('pipenv --venv 2>/dev/null | xargs basename 2>/dev/null')
    if v:shell_error == 0 && !empty(trim(pipenv_project))
      return trim(pipenv_project)
    endif
    return 'pipenv'
  endif
  return ''
endfunction

" Markdown settings
let g:vim_markdown_folding_disabled = 0
let g:vim_markdown_math = 1
let g:vim_markdown_toc_autofit = 1
let g:vim_markdown_new_list_item_indent = 2

" Goyo settings
let g:goyo_width = 88
let g:goyo_linenr = 0

" Limelight settings
let g:limelight_default_coefficient = 0.7
let g:limelight_paragraph_span = 1
