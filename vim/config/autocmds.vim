autocmd BufNewFile,BufRead Dockerfile set filetype=dockerfile" File type detection
autocmd BufNewFile,BufRead *.env set filetype=sh
autocmd BufNewFile,BufRead *.env.* set filetype=sh
autocmd BufNewFile,BufRead *.toml set filetype=toml
autocmd BufNewFile,BufRead requirements*.txt set filetype=requirements
autocmd BufNewFile,BufRead Pipfile set filetype=toml
" Comprehensive shell file detection
autocmd BufNewFile,BufRead *.sh,*.bash,*.zsh,*.ksh set filetype=sh
autocmd BufNewFile,BufRead *alias*,*aliases set filetype=sh
autocmd BufNewFile,BufRead .bashrc,.zshrc,.bash_profile,.zprofile,.bash_aliases set filetype=sh
autocmd BufNewFile,BufRead bashrc,zshrc,bash_profile,zprofile set filetype=sh
" Global ALE fixers

" Tags configuration
set tags=tags;

" Persistent Cursor Position
autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

" C/C ++ setting
autocmd FileType c,cpp setlocal cindent
autocmd FileType c,cpp setlocal commentstring=//\ %s
autocmd FileType c,cpp setlocal shiftwidth=4 tabstop=4

" SCALA setting
autocmd BufRead,BufNewFile *.scala,*.sc set filetype=scala
autocmd FileType scala setlocal shiftwidth=2 tabstop=2
autocmd FileType scala setlocal commentstring=//\ %s

" Better CSV handling
autocmd FileType csv setlocal nowrap
autocmd FileType csv setlocal scrollbind

" Quick CSV column alignment
autocmd FileType csv nnoremap <buffer> <leader>a :%!column -t<CR>

" Goyo + Limelight integration
autocmd! User GoyoEnter Limelight
autocmd! User GoyoLeave Limelight!
