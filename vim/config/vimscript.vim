" Vimscript development settings
autocmd FileType vim setlocal foldmethod=marker
autocmd FileType vim setlocal foldmarker={{{,}}}
autocmd FileType vim setlocal keywordprg=:help
autocmd FileType vim setlocal iskeyword+=:
autocmd FileType vim setlocal iskeyword+=#
autocmd FileType vim setlocal tabstop=2 shiftwidth=2

" Better syntax highlighting for Vim files
autocmd FileType vim syntax sync minlines=100

" Handy mappings for Vim development
autocmd FileType vim nnoremap <buffer> <leader>so :source %<CR>
autocmd FileType vim nnoremap <buffer> K :help <C-r><C-w><CR>

" Check syntax without saving
function! CheckVimSyntax()
  try
    execute 'source ' . expand('%')
    echo "✓ Syntax OK"
  catch
    echo "✗ Syntax Error: " . v:exception
  endtry
endfunction

autocmd FileType vim nnoremap <buffer> <leader>c :call CheckVimSyntax()<CR>
