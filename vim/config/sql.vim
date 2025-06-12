" SQL-specific settings
autocmd FileType sql setlocal commentstring=--\ %s
autocmd BufWritePre *.sql :ALEFix

" SQLFluff configuration
let g:ale_sql_sqlfluff_options = '--dialect postgres'

" Dadbod mappings
autocmd FileType sql nmap <buffer> <leader>r <Plug>(DB_Execute)
autocmd FileType sql vmap <buffer> <leader>r <Plug>(DB_Execute)
