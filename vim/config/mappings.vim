" Plugin mappings
noremap <leader>] :YcmCompleter GoTo<cr>
noremap <f5> :UndotreeToggle<cr>
nmap <silent> <leader>aj :ALENext<cr>
nmap <silent> <leader>ak :ALEPrevious<cr>
nmap <silent> <leader>af :ALEFix<cr>

" Navigation disables
inoremap <Down> <Nop>
inoremap <Left> <Nop>
inoremap <Right> <Nop>
inoremap <Up> <Nop>
nnoremap <Down> <Nop>
nnoremap <Left> <Nop>
nnoremap <Right> <Nop>
nnoremap <Up> <Nop>
vnoremap <Down> <Nop>
vnoremap <Left> <Nop>
vnoremap <Right> <Nop>
vnoremap <Up> <Nop>

" RSI-style mappings
inoremap        <C-A> <C-O>^
inoremap   <C-X><C-A> <C-A>
cnoremap        <C-A> <Home>
cnoremap   <C-X><C-A> <C-A>
inoremap <expr> <C-B> getline('.')=~'^\s*$'&&col('.')>strlen(getline('.'))?"0\<C-D>\<Esc>kJs":"\<Left>"
cnoremap        <C-B> <Left>
inoremap <expr> <C-D> col('.')>strlen(getline('.'))?"\<C-D>":"\<Del>"
cnoremap <expr> <C-D> getcmdpos()>strlen(getcmdline())?"\<C-D>":"\<Del>"
inoremap <expr> <C-E> col('.')>strlen(getline('.'))<bar><bar>pumvisible()?"\<C-E>":"\<End>"
inoremap <expr> <C-F> col('.')>strlen(getline('.'))?"\<C-F>":"\<Right>"
cnoremap <expr> <C-F> getcmdpos()>strlen(getcmdline())?&cedit:"\<Right>"

" Quick reload mapping
nnoremap <leader>vr :source $MYVIMRC<CR>

" Terminal toggle
nnoremap <leader>t :terminal<CR>

" Search and replace word under cursor
nnoremap <leader>sr :%s/\<<C-r><C-w>\>//g<Left><Left>
" Search and replace visual selection
vnoremap <leader>sr "hy:%s/<C-r>h//g<Left><Left>
" Search for selected text creat issue with copy in clipboard
" vnoremap * "hy/\V<C-r>=escape(@h,'/\')<CR><CR>

" Quick window resizing
nnoremap <silent> <C-Left> :vertical resize -5<CR>
nnoremap <silent> <C-Right> :vertical resize +5<CR>
nnoremap <silent> <C-Up> :resize +5<CR>
nnoremap <silent> <C-Down> :resize -5<CR>

" Clear search highlighting
nnoremap <leader><space> :nohlsearch<CR>

" Quick formatting
nnoremap <leader>= gg=G``

" Add FZF mappings (since you have the plugin)
nnoremap <C-p> :Files<CR>
nnoremap <leader>b :Buffers<CR>
nnoremap <leader>rg :Rg<CR>
nnoremap <leader>/ :BLines<CR>

" Add vim develepmetnt
" Vimscript development helpers (only in .vim files)
autocmd FileType vim nnoremap <buffer> <leader>R :source %<CR>:echo "Reloaded " . expand('%')<CR>
autocmd FileType vim nnoremap <buffer> <leader>H :help <C-r>=expand('<cword>')<CR><CR>

" Goyo + Limelight keybindings
nnoremap <leader>gy :Goyo<CR>
nnoremap <leader>ll :Limelight!!<CR>
