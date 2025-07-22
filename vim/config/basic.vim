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


" Theme toggle function: onedark → PaperColor(light) → PaperColor(dark+no#)
function! ToggleTheme()
    if &background == "light" && g:colors_name == "PaperColor"
        " Light PaperColor → Dark PaperColor (no numbers)
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
        " Dark PaperColor → onedark (with numbers)
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
        " onedark or any other → Light PaperColor (with numbers)
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

" Map to <Leader>th (theme) - good mnemonic and unlikely to conflict
nnoremap <Leader>tt :call ToggleTheme()<CR>
" Force interactive shell to load .zshrc and Powerlevel10k
set shell=/bin/zsh\ -i

" Basic terminal settings
if has('terminal')
    let g:terminal_height = float2nr(&lines / 3)
    set termwinsize=10x0
    set termwinscroll=10000
endif

" Environment variables for proper color support
let $TERM = 'xterm-256color'
let $COLORTERM = 'truecolor'

" Simple terminal function
function! OpenTerminal()
    execute 'terminal ++close ++rows=' . g:terminal_height
    setlocal nonumber norelativenumber
    normal! i
endfunction

" Simple mapping
nnoremap <leader>pt :call OpenTerminal()<CR>
