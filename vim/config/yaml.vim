" YAML-specific settings
autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab


" Fix YAML on save
autocmd BufWritePre *.yaml,*.yml :ALEFix
