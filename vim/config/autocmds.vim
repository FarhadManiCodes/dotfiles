" Tags configuration
set tags=tags;

" File type detection
augroup filetype_detection
  autocmd!
  autocmd BufNewFile,BufRead Dockerfile set filetype=dockerfile
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

  autocmd BufRead,BufNewFile *.scala,*.sc set filetype=scala
augroup END

" Persistent cursor position
augroup persistent_cursor
  autocmd!
  autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
augroup END

" Per-filetype tweaks
augroup filetype_tweaks
  autocmd!
  " C/C++
  autocmd FileType c,cpp setlocal cindent
  autocmd FileType c,cpp setlocal commentstring=//\ %s
  autocmd FileType c,cpp setlocal shiftwidth=4 tabstop=4

  " Scala
  autocmd FileType scala setlocal shiftwidth=2 tabstop=2
  autocmd FileType scala setlocal commentstring=//\ %s

  " CSV
  autocmd FileType csv setlocal nowrap
  autocmd FileType csv setlocal scrollbind
  autocmd FileType csv nnoremap <buffer> <leader>a :%!column -t<CR>
augroup END

" Goyo + Limelight integration
augroup goyo_limelight
  autocmd!
  autocmd User GoyoEnter Limelight
  autocmd User GoyoLeave Limelight!
augroup END
