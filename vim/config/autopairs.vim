" ============================================================================
" Auto-pairs Configuration - Comprehensive but Organized
" ============================================================================

" ----------------------------------------------------------------------------
" Basic Settings
" ----------------------------------------------------------------------------
let g:AutoPairsMapCR = 1
let g:AutoPairsMapSpace = 1
let g:AutoPairsMapBackspace = 1
let g:AutoPairsFlyMode = 1
let g:AutoPairsSmartQuotes = 1

" ----------------------------------------------------------------------------
" Shortcuts
" ----------------------------------------------------------------------------
let g:AutoPairsShortcutToggle = '<M-p>'     " Alt+p: toggle on/off
let g:AutoPairsShortcutFastWrap = '<M-e>'   " Alt+e: fast wrap selection
let g:AutoPairsShortcutJump = '<M-n>'       " Alt+n: jump to next pair

" ----------------------------------------------------------------------------
" Default Pairs
" ----------------------------------------------------------------------------
let g:AutoPairs = {
  \ '(': ')',
  \ '[': ']',
  \ '{': '}',
  \ '"': '"',
  \ "'": "'",
  \ '`': '`'
\ }

" ----------------------------------------------------------------------------
" Filetype-Specific Rules (The Complex Part You Want!)
" ----------------------------------------------------------------------------
augroup autopairs_filetype_config
  autocmd!

  " Python: Triple quotes for docstrings
  autocmd FileType python let b:AutoPairs = extend(copy(g:AutoPairs), {
    \ '"""': '"""',
    \ "'''": "'''"
  \ })

  " JavaScript/TypeScript: Template literals
  autocmd FileType javascript,typescript,jsx,tsx let b:AutoPairs = copy(g:AutoPairs)

  " HTML/XML: Angle brackets for tags
  autocmd FileType html,xml,vue let b:AutoPairs = extend(copy(g:AutoPairs), {
    \ '<': '>'
  \ })

  " Vim: No single quotes (they're comments!)
  autocmd FileType vim let b:AutoPairs = filter(copy(g:AutoPairs), 'v:key != "'"'"'"')

  " Shell: Conservative with quotes
  autocmd FileType sh,bash,zsh let b:AutoPairs = {
    \ '(': ')',
    \ '[': ']',
    \ '{': '}',
    \ '"': '"'
  \ }

  " JSON: Only essential pairs
  autocmd FileType json let b:AutoPairs = {
    \ '"': '"',
    \ '[': ']',
    \ '{': '}'
  \ }

  " YAML: Avoid quote conflicts
  autocmd FileType yaml,yml let b:AutoPairs = {
    \ '[': ']',
    \ '{': '}',
    \ '"': '"'
  \ }

  " SQL: No single quotes (they're strings)
  autocmd FileType sql let b:AutoPairs = {
    \ '(': ')',
    \ '[': ']',
    \ '"': '"'
  \ }

  " C/C++: Include angle brackets for templates
  autocmd FileType c,cpp let b:AutoPairs = extend(copy(g:AutoPairs), {
    \ '<': '>'
  \ })

  " Markdown: Conservative approach
  autocmd FileType markdown let b:AutoPairs = {
    \ '(': ')',
    \ '[': ']',
    \ '"': '"',
    \ '`': '`'
  \ }
augroup END

" ----------------------------------------------------------------------------
" Plugin Compatibility
" ----------------------------------------------------------------------------
" YouCompleteMe: Ensure Enter works with completion
if exists('g:loaded_youcompleteme')
  let g:AutoPairsCRKey = '<CR>'
endif

" FZF: Disable in search buffers
if exists('g:loaded_fzf')
  autocmd FileType fzf let b:AutoPairs = {}
endif

" Terminal: Disable in terminal mode
if has('terminal')
  autocmd TerminalOpen * let b:AutoPairs = {}
endif

" ----------------------------------------------------------------------------
" Utility Functions & Commands
" ----------------------------------------------------------------------------
function! AutoPairsStatus()
  if exists('b:AutoPairs')
    echo 'Buffer AutoPairs: ' . string(keys(b:AutoPairs))
  else
    echo 'Using global AutoPairs: ' . string(keys(g:AutoPairs))
  endif
endfunction

function! AutoPairsQuickDisable()
  let b:AutoPairs = {}
  echo "AutoPairs disabled for this buffer"
endfunction

function! AutoPairsQuickEnable()
  unlet! b:AutoPairs
  echo "AutoPairs restored to default"
endfunction

" ----------------------------------------------------------------------------
" Convenient Mappings
" ----------------------------------------------------------------------------
nnoremap <leader>ap :call AutoPairsStatus()<CR>
nnoremap <leader>ad :call AutoPairsQuickDisable()<CR>
nnoremap <leader>ae :call AutoPairsQuickEnable()<CR>

" Manual surround for visual selections (backup when auto-pairs isn't enough)
vnoremap <leader>( <Esc>`>a)<Esc>`<i(<Esc>
vnoremap <leader>[ <Esc>`>a]<Esc>`<i[<Esc>
vnoremap <leader>{ <Esc>`>a}<Esc>`<i{<Esc>
vnoremap <leader>" <Esc>`>a"<Esc>`<i"<Esc>

" ----------------------------------------------------------------------------
" Debug Command (for when things go wrong)
" ----------------------------------------------------------------------------
command! AutoPairsDebug echo "AutoPairs loaded:" . (exists('g:loaded_autopairs') ? 'Yes' : 'No') .
  \ " | Global pairs:" . string(g:AutoPairs) .
  \ " | Buffer override:" . (exists('b:AutoPairs') ? string(b:AutoPairs) : 'None')
