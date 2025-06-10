autocmd BufNewFile,BufRead *.sh,*.bash,*.zsh set filetype=sh
autocmd BufNewFile,BufRead Dockerfile set filetype=dockerfile" File type detection
autocmd BufNewFile,BufRead *.env set filetype=sh
autocmd BufNewFile,BufRead *.env.* set filetype=sh
autocmd BufNewFile,BufRead *.toml set filetype=toml
autocmd BufNewFile,BufRead requirements*.txt set filetype=requirements
autocmd BufNewFile,BufRead Pipfile set filetype=toml

" Global ALE fixers

" Tags configuration
set tags=tags;

" Persistent Cursor Position
autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
