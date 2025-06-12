" terminal and shell
set shell=/bin/zsh
if has('terminal')
    let g:terminal_height = float2nr(&lines / 3)
    set termwinsize=10x0
endif
" Basic settings
syntax on
filetype plugin indent on
set nocompatible
set autoindent
set expandtab
set tabstop=4
set shiftwidth=4
set backspace=indent,eol,start
set number relativenumber
set splitright
set splitbelow
set hlsearch
set incsearch
set clipboard=unnamed,unnamedplus
set wildmenu
set wildoptions=pum
set undofile
set undodir=~/.vim/undodir
set undolevels=1000
set undoreload=10000
set laststatus=2
set ttimeout
set ttimeoutlen=1
" Startup Time Optimization
set ttyfast
set lazyredraw

" SSH Performance Settings
set timeout timeoutlen=1000 ttimeoutlen=50
set updatetime=300
set shortmess+=I  " Remove intro message
set noshowcmd     " Don't show partial commands (faster over SSH)

"" relative numbers when navigating, absolute when editing.
augroup numbertoggle
  autocmd!
  autocmd BufEnter,FocusGained,InsertLeave,WinEnter * if &nu && mode() != "i" | set rnu   | endif
  autocmd BufLeave,FocusLost,InsertEnter,WinLeave   * if &nu                  | set nornu | endif
augroup END

" True color support
if (has("nvim"))
    let $NVIM_TUI_ENABLE_TRUE_COLOR=1
endif
if (has("termguicolors"))
    set termguicolors
endif
colorscheme onedark

" Folding defaults
set foldlevelstart=5
set foldcolumn=1
highlight Folded ctermfg=Black ctermbg=DarkGrey

" Cursor shape settings
if has("autocmd")
  au VimEnter,InsertLeave * silent execute '!echo -ne "\e[1 q"' | redraw!
  au InsertEnter,InsertChange *
    \ if v:insertmode == 'i' |
    \   silent execute '!echo -ne "\e[6 q"' | redraw! |
    \ elseif v:insertmode == 'r' |
    \   silent execute '!echo -ne "\e[3 q"' | redraw! |
    \ endif
  au VimLeave * silent execute '!echo -ne "\e[ q"' | redraw!
endif
