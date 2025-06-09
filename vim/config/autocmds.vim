autocmd BufNewFile,BufRead *.sh,*.bash,*.zsh set filetype=sh
autocmd BufNewFile,BufRead Dockerfile set filetype=dockerfile" File type detection
autocmd BufNewFile,BufRead *.env set filetype=sh
autocmd BufNewFile,BufRead *.env.* set filetype=sh

" Global ALE fixers

" Tags configuration
set tags=tags;

