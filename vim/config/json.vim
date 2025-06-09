" JSON-specific settings
autocmd FileType json setlocal ts=2 sts=2 sw=2 expandtab

" ALE JSON configuration
let g:ale_json_jq_options = '--indent 2'

" Fix JSON on save
autocmd BufWritePre *.json :ALEFix
