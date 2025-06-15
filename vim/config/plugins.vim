" Plugin Management
let g:plug_timeout = 300
call plug#begin()

Plug 'mileszs/ack.vim'
Plug 'tpope/vim-unimpaired'
Plug 'tpope/vim-vinegar'
Plug 'tomtom/tcomment_vim'
Plug 'ycm-core/YouCompleteMe', { 'do': './install.py --clang-completer' }
Plug 'dense-analysis/ale'
Plug 'mbbill/undotree'
Plug 'itchyny/lightline.vim'
Plug 'christoomey/vim-tmux-navigator'
Plug 'tpope/vim-fugitive'
Plug 'vim-python/python-syntax'
Plug 'tpope/vim-dadbod'
Plug 'AndrewRadev/splitjoin.vim'
Plug 'FarhadManiCodes/vim-envx'
Plug 'mechatroner/rainbow_csv'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'tpope/vim-surround'
Plug 'jiangmiao/auto-pairs'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-obsession'
call plug#end()
