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
if has('ios')
    command! -nargs=* -bang IOldFiles
                \ call find_file#OldFileList('<bang>', '', <q-args>, 'iolddocs')
endif
