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
            \ call find_file#QuickFind('', <q-args>)
command! -nargs=* -complete=file_in_path SplitFileFind
            \ call find_file#QuickFind('Split', <q-args>)
command! -nargs=* -complete=file_in_path VertFileFind
            \ call find_file#QuickFind('Vert', <q-args>)
command! -nargs=* OldFiles
            \ call find_file#OldFileList('', '', <q-args>)
command! -nargs=* SplitOldFiles
            \ call find_file#OldFileList('', 'Split', <q-args>)
command! -nargs=* VertOldFiles
            \ call find_file#OldFileList('', 'Vert', <q-args>)
nnoremap <Leader>gg :FileFind 
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

    nnoremap ,gf :FasdFiles 
    nnoremap ,gd :FasdDirs 
    nnoremap ,ga :FasdAll 
endif
if has('ios')
    command! -nargs=* -bang IOldFiles
                \ call find_file#OldFileList('<bang>', '', <q-args>, 'iolddocs')
endif
