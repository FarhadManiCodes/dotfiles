" SQL-specific settings
autocmd FileType sql setlocal commentstring=--\ %s
autocmd BufWritePre *.sql :ALEFix

" SQLFluff configuration
let g:ale_sql_sqlfluff_options = '--dialect postgres'

" Dadbod mappings
autocmd FileType sql nmap <buffer> <F5> :execute 'DB ' . getline('.')<CR>
autocmd FileType sql vmap <buffer> <F5> :DB<CR>
