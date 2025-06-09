" File type detection
autocmd BufNewFile,BufRead *.env set filetype=sh
autocmd BufNewFile,BufRead *.env.* set filetype=sh

" Global ALE fixers

" Tags configuration
set tags=tags;

" Auto-reload vimrc when saved
autocmd BufWritePost $MYVIMRC source $MYVIMRC

" Auto-reload config when any .vim file changes
augroup reload_vimrc
  autocmd!
  autocmd BufWritePost $MYVIMRC nested source $MYVIMRC
  autocmd BufWritePost ~/.vim/config/*.vim nested source $MYVIMRC
augroup END
