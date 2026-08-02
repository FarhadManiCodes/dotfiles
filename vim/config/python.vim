" Python-specific settings
" NOTE: these use `set`, not `setlocal`, so they leak into every later buffer
" once a Python file has been opened. Left as-is deliberately for now.
augroup python_settings
  autocmd!
  autocmd FileType python set foldmethod=indent
  autocmd FileType python set expandtab
  autocmd FileType python set tabstop=4
  autocmd FileType python set softtabstop=4
  autocmd FileType python set shiftwidth=4
  autocmd FileType python set textwidth=79
  autocmd FileType python set autoindent
  autocmd FileType python set fileformat=unix
  autocmd FileType python set encoding=utf-8
  autocmd BufWritePost *.py silent! !ctags -R &

  " Pylint integration
  autocmd FileType python setlocal makeprg=pylint\ --reports=n\ --msg-template=\"{path}:{line}:\ {msg_id}\ {symbol},\ {obj}\ {msg}\"\ %:p
  autocmd FileType python setlocal errorformat=%f:%l:\ %m
augroup END

" Python syntax highlighting
let g:python_highlight_all = 1
