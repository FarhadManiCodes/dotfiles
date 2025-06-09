" Python-specific settings
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

" Python syntax highlighting
let g:python_highlight_all = 1

" ALE Python settings
let g:ale_python_flake8_options = '--max-line-length=88'
let g:ale_python_black_options = '--line-length 88'
let g:ale_python_auto_pipenv = 1


" Pylint integration
autocmd FileType python setlocal makeprg=pylint\ --reports=n\ --msg-template=\"{path}:{line}:\ {msg_id}\ {symbol},\ {obj}\ {msg}\"\ %:p
autocmd FileType python setlocal errorformat=%f:%l:\ %m
