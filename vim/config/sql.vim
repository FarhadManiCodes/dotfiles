" SQL-specific settings
let g:ale_sql_sqlfmt_options = '-u'
let g:ale_sql_sqlfmt_options = '--uppercase'
autocmd FileType sql setlocal commentstring=--\ %s
autocmd BufWritePre *.sql :ALEFix


" Dadbod mappings
autocmd FileType sql nmap <buffer> <leader>r <Plug>(DB_Execute)
autocmd FileType sql vmap <buffer> <leader>r <Plug>(DB_Execute)
