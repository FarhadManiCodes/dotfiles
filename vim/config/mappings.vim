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

" Auto-pairs
inoremap ' ''<esc>i
inoremap " ""<esc>i
inoremap ( ()<esc>i
inoremap { {}<esc>i
inoremap [ []<esc>i

" Quick reload mapping
nnoremap <leader>vr :source $MYVIMRC<CR>
