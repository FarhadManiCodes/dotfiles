" ============================================================================
" Vi Tiny Compatible Configuration
" Extracted from your full vim setup for VIM Tiny version
" ============================================================================

" Basic settings from your basic.vim that work in tiny
set number
set autoindent
set smartindent
set tabstop=4
set shiftwidth=4
set expandtab
set backspace=indent,eol,start
set hlsearch
set incsearch
set showmode
set showmatch
set ruler
set splitright
set splitbelow
set wildmenu
set laststatus=2

" Performance settings from your config
set ttyfast
set timeout timeoutlen=1000 ttimeoutlen=50

" Basic mappings from your mappings.vim
map <leader>w :w<CR>
map <leader>q :q<CR>
map <leader><space> :nohlsearch<CR>

" Window navigation (from your config)
map <C-h> <C-w>h
map <C-j> <C-w>j
map <C-k> <C-w>k
map <C-l> <C-w>l

" Search and replace (simplified from your mappings)
map <leader>sr :%s/\<<C-r><C-w>\>//g<Left><Left>

" Quick formatting
map <leader>= gg=G``

" Basic highlighting (works even without syntax support)
highlight Search ctermfg=black ctermbg=180  " Yellow background
highlight IncSearch ctermfg=black ctermbg=red
highlight LineNr ctermfg=140
highlight Visual ctermbg=darkblue

" Colors based on terminal capability
if &t_Co >= 8
    highlight Comment ctermfg=green
    highlight String ctermfg=red
    highlight Keyword ctermfg=blue
    highlight Number ctermfg=yellow
endif

" File type settings from your configs
autocmd BufRead,BufNewFile *.py set tabstop=4 shiftwidth=4 expandtab
autocmd BufRead,BufNewFile *.yml,*.yaml set tabstop=2 shiftwidth=2 expandtab
autocmd BufRead,BufNewFile *.json set tabstop=2 shiftwidth=2 expandtab
autocmd BufRead,BufNewFile *.sh,*.bash set tabstop=2 shiftwidth=2 expandtab

" File type detection from your autocmds.vim
autocmd BufNewFile,BufRead *.env set filetype=sh
autocmd BufNewFile,BufRead *.env.* set filetype=sh
autocmd BufNewFile,BufRead Dockerfile set filetype=dockerfile
autocmd BufNewFile,BufRead requirements*.txt set filetype=requirements

" Persistent cursor position (from your autocmds.vim)
autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

" Disable arrow keys in insert mode (from your mappings.vim)
inoremap <Down> <Nop>
inoremap <Left> <Nop>
inoremap <Right> <Nop>
inoremap <Up> <Nop>
