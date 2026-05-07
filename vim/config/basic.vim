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
set ttimeoutlen=50

" Performance
set ttyfast
set lazyredraw
set timeout timeoutlen=1000
set updatetime=300
set shortmess+=I
set noshowcmd

" Shell (interactive so .zshrc and prompt are loaded)
set shell=/bin/zsh\ -i

" Terminal settings
if has('terminal')
    let g:terminal_height = float2nr(&lines / 3)
    set termwinsize=10x0
    set termwinscroll=10000
endif

" Relative numbers when navigating, absolute when editing
augroup numbertoggle
  autocmd!
  autocmd BufEnter,FocusGained,InsertLeave,WinEnter * if &nu && mode() != "i" | set rnu   | endif
  autocmd BufLeave,FocusLost,InsertEnter,WinLeave   * if &nu                  | set nornu | endif
augroup END

" True color support
if (has("termguicolors"))
    set termguicolors
endif
let $COLORTERM = 'truecolor'

" Cursor shape (native vim terminal codes — no shell spawning per mode change)
let &t_SI = "\e[6 q"   " beam in insert
let &t_SR = "\e[3 q"   " underline in replace
let &t_EI = "\e[1 q"   " block in normal
let &t_ti .= "\e[1 q"  " block on enter
let &t_te .= "\e[ q"   " reset on exit

" Folding defaults
set foldlevelstart=5
set foldcolumn=1
highlight Folded ctermfg=Black ctermbg=DarkGrey

set background=dark

" Theme toggle: onedark → PaperColor light → PaperColor dark
function! ToggleTheme()
    if &background == "light" && g:colors_name == "PaperColor"
        set background=dark
        colorscheme PaperColor
        set nonumber norelativenumber
        if exists('g:lightline')
            let g:lightline.colorscheme = "PaperColor_dark"
            call lightline#init()
            call lightline#colorscheme()
        endif
        echo "Theme: PaperColor Dark (no numbers)"
    elseif &background == "dark" && g:colors_name == "PaperColor"
        set background=dark
        colorscheme onedark
        set number relativenumber
        if exists('g:lightline')
            let g:lightline.colorscheme = "one"
            call lightline#init()
            call lightline#colorscheme()
        endif
        echo "Theme: OneDark (with numbers)"
    else
        set background=light
        colorscheme PaperColor
        set number relativenumber
        if exists('g:lightline')
            let g:lightline.colorscheme = "PaperColor"
            call lightline#init()
            call lightline#colorscheme()
        endif
        echo "Theme: PaperColor Light (with numbers)"
    endif
endfunction
nnoremap <Leader>tt :call ToggleTheme()<CR>

" Open terminal split
function! OpenTerminal()
    execute 'terminal ++close ++rows=' . g:terminal_height
    setlocal nonumber norelativenumber
    normal! i
endfunction
nnoremap <leader>pt :call OpenTerminal()<CR>

" Load colorscheme after plugins are loaded
augroup load_colorscheme
    autocmd!
    autocmd VimEnter * ++nested colorscheme onedark
augroup END
