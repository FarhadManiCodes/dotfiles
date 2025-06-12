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
