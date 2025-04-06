scriptencoding utf-8
" vim: set fdm=marker:
" ============================================================================
" FIND FILES/BUFFERS
" ============================================================================

command! -nargs=* -bang BufferFind
            \ call find_file#QuickBuffer('<bang>', '', <q-args>)
command! -nargs=* -bang SplitBufferFind
            \ call find_file#QuickBuffer('<bang>', 'Split', <q-args>)
command! -nargs=* -bang VertBufferFind
            \ call find_file#QuickBuffer('<bang>', 'Vert', <q-args>)
command! -nargs=* -complete=file_in_path FileFind
            \ call find_file#QuickFile('', <q-args>)
command! -nargs=* -complete=file_in_path SplitFileFind
            \ call find_file#QuickFile('Split', <q-args>)
command! -nargs=* -complete=file_in_path VertFileFind
            \ call find_file#QuickFile('Vert', <q-args>)
command! -nargs=* OldFiles
            \ call find_file#OldFileList('', '', <q-args>)
command! -nargs=* SplitOldFiles
            \ call find_file#OldFileList('', 'Split', <q-args>)
command! -nargs=* VertOldFiles
            \ call find_file#OldFileList('', 'Vert', <q-args>)
if !hasmapto("FileFind")
    nnoremap <Leader>ff :FileFind<Space>
    nnoremap <Leader>fd :FileFind \.\(tex\\|md\)$<Space>
    nnoremap <Leader>ft :FileFind \.tex$<Space>
    nnoremap <Leader>fm :FileFind \.md$<Space>
    nnoremap <Leader>fv :FileFind \.vim$<Space>
    nnoremap <Leader>fp :FileFind \.py$<Space>
endif
if executable('fasd')
    command! -nargs=* FasdFiles
                \ call find_file#Fasd('', <q-args>, 'FasdFiles')
    command! -nargs=* SplitFasdFiles
                \ call find_file#Fasd('Split', <q-args>, 'FasdFiles')
    command! -nargs=* VertFasdFiles
                \ call find_file#Fasd('Vert', <q-args>, 'FasdFiles')

    command! -nargs=* FasdDirs
                \ call find_file#Fasd('', <q-args>, 'FasdDirs')
    command! -nargs=* SplitFasdDirs
                \ call find_file#Fasd('Split', <q-args>, 'FasdDirs')
    command! -nargs=* VertFasdDirs
                \ call find_file#Fasd('Vert', <q-args>, 'FasdDirs')

    command! -nargs=* FasdAll
                \ call find_file#Fasd('', <q-args>, 'FasdAll')
    command! -nargs=* SplitFasdAll
                \ call find_file#Fasd('Split', <q-args>, 'FasdAll')
    command! -nargs=* VertFasdAll
                \ call find_file#Fasd('Vert', <q-args>, 'FasdAll')

    if !hasmapto("FasdFiles")
        nnoremap <Leader>fF :FasdFiles 
    endif
    if !hasmapto("FasdDirs")
        nnoremap <Leader>fD :FasdDirs 
    endif
    if !hasmapto("FasdAll")
        nnoremap <Leader>fa :FasdAll 
    endif
endif
command! -nargs=* AndGrep call find_file#AndGrep(<q-args>, '*')

if !exists('g:findFilesGlobList')
    let g:findFilesGlobList = ['**/*']
endif

if !exists('g:findFilesIgnoreList')
    " Default is 'wildignore' list, taking out wildcards
    let g:findFilesIgnoreList = split(substitute(&wildignore, '\*', '', 'g'), ',')
endif
" Need to append each item with '!' so that they get ignored
try
    if g:findFilesIgnoreList[0][0] !=# "!"
        call map(g:findFilesIgnoreList, '"!" .. v:val')
    endif
catch /684/
endtry

if has('ios')
    command! -nargs=* -bang IOldFiles
                \ call find_file#OldFileList('<bang>', '', <q-args>, 'iolddocs')
endif
