" Plugin Management
let g:plug_timeout = 300
call plug#begin()

" Essential editing enhancements (5)
Plug 'jiangmiao/auto-pairs'           " Auto-close brackets/quotes
Plug 'tpope/vim-surround'             " Surround text with pairs
Plug 'tomtom/tcomment_vim'            " Smart commenting
Plug 'tpope/vim-repeat'               " Repeat plugin commands with .
Plug 'tpope/vim-unimpaired'           " Paired bracket mappings

" UI & themes (3)
Plug 'itchyny/lightline.vim'          " Minimal statusline
Plug 'NLKNguyen/papercolor-theme'     " Light theme
Plug 'joshdick/onedark.vim'           " Dark theme

" Markdown & writing (3)
Plug 'preservim/vim-markdown'         " Markdown support
Plug 'junegunn/goyo.vim'              " Distraction-free writing
Plug 'junegunn/limelight.vim'         " Paragraph focus

" Integrations (3)
Plug 'christoomey/vim-tmux-navigator' " Vim/tmux navigation
Plug 'mechatroner/rainbow_csv'        " CSV column highlighting
Plug 'FarhadManiCodes/vim-envx'       " Custom env plugin

call plug#end()
