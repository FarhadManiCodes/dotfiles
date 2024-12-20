" add the basic congiguration
syntax on " Enable syntax highlighting.
filetype plugin indent on " Enable file type based options.

set nocompatible " Don't run in backwards compatible mode.
set autoindent " Respect indentation when starting new line.

set expandtab " Expand tabs to spaces. Essential in Python.
set tabstop=4 " Number of spaces tab is counted for.
set shiftwidth=4 " Number of spaces to use for autoindent.
set backspace=2 " Fix backspace behavior on most terminals.


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

Plug 'mileszs/ack.vim'
Plug 'tpope/vim-unimpaired'
Plug 'tpope/vim-vinegar'
Plug 'tpope/vim-commentary'
Plug 'ycm-core/YouCompleteMe'
Plug 'mbbill/undotree'
Plug 'itchyny/lightline.vim'

call plug#end()


" Some python specific settings

autocmd filetype python set expandtab
autocmd filetype python set tabstop=4
autocmd filetype python set softtabstop=4
autocmd filetype python set shiftwidth=4
autocmd filetype python set textwidth=79
autocmd filetype python set autoindent 
autocmd filetype python set fileformat=unix
autocmd filetype python set encoding=utf-8

" remapping commands
"
noremap <leader>] :YcmCompleter GoTo<cr>
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
cnoremap <expr> <C-D> getcmdpos()>strlen(getcmdline())?"\<Lt>C-D>":"\<Lt>Del>"

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
