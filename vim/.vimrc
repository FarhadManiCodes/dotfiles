" add the basic congiguration
syntax on " Enable syntax highlighting.
filetype plugin indent on " Enable file type based options.

set nocompatible " Don't run in backwards compatible mode.
set autoindent " Respect indentation when starting new line.

set expandtab " Expand tabs to spaces. Essential in Python.
set tabstop=4 " Number of spaces tab is counted for.
set shiftwidth=4 " Number of spaces to use for autoindent.
set backspace=indent,eol,start
set number relativenumber
set splitright
set splitbelow
"Use 24-bit (true-color) mode in Vim/Neovim when outside tmux.
"If you're using tmux version 2.2 or later, you can remove the outermost $TMUX check and use tmux's 24-bit color support
"(see < http://sunaku.github.io/tmux-24bit-color.html#usage > for more information.)
if (has("nvim"))
"For Neovim 0.1.3 and 0.1.4 < https://github.com/neovim/neovim/pull/2198 >
    let $NVIM_TUI_ENABLE_TRUE_COLOR=1
endif
"For Neovim > 0.1.5 and Vim > patch 7.4.1799 < https://github.com/vim/vim/commit/61be73bb0f965a895bfb064ea3e55476ac175162 >
"Based on Vim patch 7.4.1770 (`guicolors` option) < https://github.com/vim/vim/commit/8a633e3427b47286869aa4b96f2bfc1fe65b25cd >
" < https://github.com/neovim/neovim/wiki/Following-HEAD#20160511 >
if (has("termguicolors"))
    set termguicolors
endif
colorscheme onedark " Change a colorscheme.

" ---------- extra tunes on movement and navigation
set wildmenu " set wildmenu on
" set wildmode=list:longest,full " Complete till longest string, then open wildmenu.
set wildoptions=pum
" set background=dark

" search setting
set hlsearch        " Highlight search result
set incsearch       " Search as you type

set clipboard=unnamed,unnamedplus " Comy into system (*, +) registers.

" Flagging unnecessary white spaces"
" Change cursor 
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

set ttimeout
set ttimeoutlen=1
set ttyfast


" to remove later folding
autocmd filetype python set foldmethod=indent
set foldlevelstart=5
set foldcolumn=1
highlight Folded ctermfg=Black
highlight Folded ctermbg=DarkGrey

" ---- Plugin Management and settings ----------

" Download and install vim-plug 
" let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
" if empty(glob(data_dir . '/autoload/plug.vim'))
  " silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  " autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
" endif
let g:plug_timeout = 300 " Increase vim-plug timeout for YCM
call plug#begin()
Plug 'mileszs/ack.vim' " ack integration
Plug 'tpope/vim-unimpaired' " pairs of helpful shortcuts
Plug 'tpope/vim-vinegar' " to open netrw
Plug 'tomtom/tcomment_vim' " commenting helpers
Plug 'ycm-core/YouCompleteMe' " Auto Complete
Plug 'mbbill/undotree' " Visualize the undo tree
Plug 'itchyny/lightline.vim' " Nicer vim status
Plug 'christoomey/vim-tmux-navigator' " better tmux integration
Plug 'tpope/vim-fugitive' " Vim plugin for Git. 
Plug 'nvie/vim-flake8'
Plug 'psf/black', { 'branch': 'stable' }
Plug 'vim-python/python-syntax'
Plug 'tpope/vim-dadbod'
Plug 'AndrewRadev/splitjoin.vim'       " Code block transformations
Plug 'FarhadManiCodes/vim-envx'
call plug#end()

" ==== Some python specific settings ===

autocmd filetype python set expandtab
autocmd filetype python set tabstop=4
autocmd filetype python set softtabstop=4
autocmd filetype python set shiftwidth=4
autocmd filetype python set textwidth=79
autocmd filetype python set autoindent 
autocmd filetype python set fileformat=unix
autocmd filetype python set encoding=utf-8

" === Python Development Enhancements ===
" Auto-format on save
autocmd BufWritePre *.py execute ':Black'
autocmd BufWritePre *.py execute ':call Flake8()'
"
" Python-syntax enhancements
let g:python_highlight_all = 1

" === Quality of Life Improvements ===
" Persistent undo history
set undofile
set undodir=~/.vim/undodir
set undolevels=1000
set undoreload=10000


" remapping commands
" YCM go to 
noremap <leader>g :YcmCompleter GoTo<cr>
" Remove newbie crutches in Insert Mode
inoremap <Down> <Nop>
inoremap <Left> <Nop>
inoremap <Right> <Nop>
inoremap <Up> <Nop>

" Remove newbie crutches in Normal Mode
nnoremap <Down> <Nop>
nnoremap <Left> <Nop>
nnoremap <Right> <Nop>
nnoremap <Up> <Nop>

" Remove newbie crutches in Visual Mode
vnoremap <Down> <Nop>
vnoremap <Left> <Nop>
vnoremap <Right> <Nop>
vnoremap <Up> <Nop>

noremap <f5> :UndotreeToggle<cr> " Map Undotree to <F5>

" some remaps from rsi
inoremap        <C-A> <C-O>^
inoremap   <C-X><C-A> <C-A>
cnoremap        <C-A> <Home>
cnoremap   <C-X><C-A> <C-A>

inoremap <expr> <C-B> getline('.')=~'^\s*$'&&col('.')>strlen(getline('.'))?"0\<Lt>C-D>\<Lt>Esc>kJs":"\<Lt>Left>"
cnoremap        <C-B> <Left>

inoremap <expr> <C-D> col('.')>strlen(getline('.'))?"\<Lt>C-D>":"\<Lt>Del>"
cnoremap <expr> <C-D> getcmggggdpos()>strlen(getcmdline())?"\<Lt>C-D>":"\<Lt>Del>"

inoremap <expr> <C-E> col('.')>strlen(getline('.'))<bar><bar>pumvisible()?"\<Lt>C-E>":"\<Lt>End>"

inoremap <expr> <C-F> col('.')>strlen(getline('.'))?"\<Lt>C-F>":"\<Lt>Right>"
cnoremap <expr> <C-F> getcmdpos()>strlen(getcmdline())?&cedit:"\<Lt>Right>"
"
"
" Immediately add a closing quotes or braces in insert mode.
inoremap ' ''<esc>i
inoremap " ""<esc>i
inoremap ( ()<esc>i
inoremap { {}<esc>i
inoremap [ []<esc>i

" tags settings
set tags=tags; " Look for tags file recursively in parent directiories.
" Regenerate tags when saving Python files.
autocmd BufWritePost *.py silent! !ctags -R &

" for lightline
set laststatus=2
let g:lightline = {
  \ 'colorscheme': 'onedark',
  \ }


" Use :make to run pylint for Python files.
autocmd filetype python setlocal makeprg=pylint\ --reports=n\ --msg-template=\"{path}:{line}:\ {msg_id}\ {symbol},\ {obj}\ {msg}\"\ %:p
autocmd filetype python setlocal errorformat=%f:%l:\ %m

