scriptencoding utf-8
" vim: set fdm=marker:
" ============================================================================
" FIND FILES/BUFFERS
" ============================================================================
function! s:FilterFileList(fileList, patternList) abort  "{{{
    " Filter a list of files using pattern. If first character of the pattern
    " is '!', keep items that do *not* match the rest of the pattern.
    let l:fileList = a:fileList
    for l:item in a:patternList
        if l:item[0] ==# '!'
            call filter(l:fileList, 'v:val !~? l:item[1:]')
        else
            call filter(l:fileList, 'v:val =~? l:item')
        endif
    endfor
    return l:fileList
endfunction
"}}}
function! s:PrintFileList(bang, files, command) abort  "{{{
    " Neatly prints a:files, and writes a:command to command line.
    redraw
    if len(a:files) == 0
        echohl WarningMsg
        echo 'No files found.'
        echo ''
        echohl None
        call feedkeys(a:command)
        return
    else
        let l:width = winwidth(0)
        " let l:height = 58
        let l:height = winheight(0) - 1
        for l:index in range(min([len(a:files), l:height]))
            echohl WarningMsg | echo l:index + 1 . '. '
            if a:bang == '!' && !buflisted(a:files[l:index])
                echohl Comment
            else
                echohl MoreMsg
            endif
            let l:name = fnamemodify(a:files[l:index], ':t')[: l:width - len(l:index + 1) - 7]
            echon l:name[: l:width]
            let l:pathLen = l:width - len(l:name[: l:width]) - len(l:index + 1) - 7
            if l:pathLen > 0
                echohl Comment | echon  ' (' .
                    \ fnamemodify(a:files[l:index], ':~:h')[: l:pathLen] .
                    \ ')'
            endif
        endfor
        if len(a:files) > l:height
            echohl Comment | echo '... [and more] ...'
        endif
        echohl None
    endif
    call feedkeys(a:command)
    if a:command =~# '\S$'
        call feedkeys(' ')
    endif
endfunction
"}}}
function! s:ParseMode(mode) abort  "{{{
    if a:mode ==# 'Split'
        return 'split |'
    elseif a:mode ==# 'Vert'
        return 'vertical split |'
    else
        return ''
    endif
endfunction
"}}}
function! find_file#QuickBuffer(bang, mode, pattern) abort  "{{{
    if a:bang == '!'
        let l:bufList = filter(range(1, bufnr('$')), 'bufexists(v:val)')
    else
        let l:bufList = filter(range(1, bufnr('$')), 'buflisted(v:val)')
    endif
    let l:commandPrefix = <SID>ParseMode(a:mode)
    let l:files = map(copy(l:bufList), 'fnamemodify(bufname(v:val), ":p")')
    if a:bang !=# '!'
        call filter(l:files, 'filereadable(fnamemodify(v:val, ":p"))')
    endif
    call sort(l:files)
    call uniq(l:files)
    let l:patternList = split(a:pattern, ' ')
    if a:pattern[-1:] =~# '\d'
        let l:number = matchstr(a:pattern, '\d\+$')
        call remove(l:patternList, -1)  " Remove last item from pattern
        call <SID>FilterFileList(l:files, l:patternList)
        if l:number > len(l:files)
            " If number is too big, assume it's part of the pattern
            call add(l:patternList, l:number)
        else
            execute l:commandPrefix 'edit ' . fnameescape(l:files[l:number - 1])
            return
        endif
    endif
    call <SID>FilterFileList(l:files, l:patternList)
    if len(l:files) == 1
        execute l:commandPrefix 'edit' fnameescape(l:files[0])
    else
        call <SID>PrintFileList(a:bang, l:files, ':' . a:mode . 'BufferFind' . a:bang . ' ' . a:pattern)
    endif
endfunction
"}}}
function! s:GetFilesFromPattern(patternString) abort  "{{{
    " Take file glob and return list of matching files. Note that `glob`bing and
    " `map`ping are expensive, so save the filelist for reuse in the next few
    " seconds, assuming the file list won't change in that time; after that,
    " generate the list again.
    let l:patternList = split(a:patternString, ' ')
    if !exists('b:quickTime') || localtime() - b:quickTime > 20
        echohl Comment
        echo '(Re)creating filelist ...'
        echohl None
        let b:quickFiles = glob('**/*', 0, 1)
        call map(b:quickFiles, 'fnamemodify(v:val, ":p")')
    endif
    let l:files = <SID>FilterFileList(copy(b:quickFiles), l:patternList)
    let b:quickTime = localtime()
    return l:files
endfunction
"}}}
function! find_file#QuickFind(mode, pattern) abort  "{{{
    " Embellished :find function. Can keep adding multiple search terms to
    " narrow the search, can select a file by number, or can send all files to
    " quickfix list.
    let l:commandPrefix = <SID>ParseMode(a:mode)
    if a:pattern =~# '\d$'
        " A number, n, at the end of the search string selects the nth found
        " file.
        let l:pattern = matchstr(a:pattern, '.\{-}\ze\d*$')
        if l:pattern !=# ''
            let l:index = matchstr(a:pattern, '\d*$')
            let l:files = <SID>GetFilesFromPattern(l:pattern)
            try
                unlet b:quickTime
                unlet b:quickFiles
                execute l:commandPrefix 'find' fnameescape(l:files[l:index - 1])
                " if executable('fasd')
                "     silent execute '!fasd -A' fnameescape(l:files[l:index - 1])
                " endif
                redraw
                return
            catch /E684/  " Index out of range: assume number is part of filename
            endtry
        endif
    elseif a:pattern[-1:] =~# '*'
        " A '*' at the end will create a qflist with all found items
        let l:pattern = a:pattern[:-2]
        let l:files = <SID>GetFilesFromPattern(l:pattern)
        let l:qflist = map(l:files, '{"filename": v:val}')
        call setqflist(l:qflist)
            call setqflist([], 'a', {'title': 'FileFind List'})
        unlet b:quickTime
        unlet b:quickFiles
        copen
        return
    endif
    " Present numbered list of found files
    let l:files = <SID>GetFilesFromPattern(a:pattern)
    if len(l:files) == 1
        unlet b:quickTime
        unlet b:quickFiles
        execute l:commandPrefix 'find' fnameescape(l:files[0])
        " if executable('fasd')
        "     silent execute '!fasd -A' fnameescape(l:files[0])
        " endif
        return
    else
        call <SID>PrintFileList('', l:files, ':' . a:mode . 'FileFind ' . a:pattern)
        return
    endif
endfunction
"}}}
function! s:GetIOldDocsList() abort  "{{{
    redir => l:ioldString
    silent iolddocs
    redir END
    let l:ioldList = split(l:ioldString, '\n')
    call map(l:ioldList, 'matchstr(v:val, ''\d\+: \zs.*'')')
    return l:ioldList
endfunction
"}}}
function! find_file#OldFileList(bang, mode, pattern, ...) abort  "{{{
    " If on iOS and iolddocs is requested, set flag
    let l:oldFileCommand = a:0 && a:1 == 'iolddocs' ? 'IOldFiles' : 'OldFiles'
    let l:commandPrefix = <SID>ParseMode(a:mode)
    if a:pattern =~# '\d$'  " if pattern ends in a number, try opening that file number
        let l:number = matchstr(a:pattern, '\d\+$')
        let l:pattern = '!\.git ' . matchstr(a:pattern, '.\{-}\ze \d\+$')
        if l:oldFileCommand == 'IOldFiles'
            let l:patternList = split(l:pattern, ' ')
            let l:ioldList = <SID>GetIOldDocsList()
            let l:oldFileList = <SID>FilterFileList(l:ioldList, l:patternList)
            if l:number <= len(l:oldFileList)  " If number is not larger than length of list
                let l:ioldFile = matchstr(l:oldFileList[l:number - 1], '/\zs[^/]*$')
                try
                    execute l:commandPrefix 'iolddocs' . a:bang . ' /' . l:ioldFile . '/'
                catch
                    echohl WarningMsg
                    echo 'Cannot open file; removing from old files list.'
                    echohl None
                    execute 'iolddocs! /' . l:ioldFile . '/'
                endtry
                return
            endif  " If number is larger, treat number as part of pattern
        else  " If not IOldFiles
            let l:oldFileList = <SID>FilterFileList(copy(v:oldfiles), split(l:pattern, ' '))
            call filter(l:oldFileList, 'filereadable(fnamemodify(v:val, ":p"))')
            if l:number <= len(l:oldFileList)
                execute l:commandPrefix 'find' fnameescape(l:oldFileList[l:number - 1])
                return
            endif  " If number is larger, treat number as part of pattern
        endif
    endif  " pattern does not contain number (or number is larger than list length)
    let l:patternList = ['!\.git '] + split(a:pattern, ' ')
    if l:oldFileCommand == 'IOldFiles'
        let l:ioldList = <SID>GetIOldDocsList()
        let l:oldFileList = <SID>FilterFileList(l:ioldList, l:patternList)
    else
        let l:oldFileList = <SID>FilterFileList(copy(v:oldfiles), l:patternList)
        call filter(l:oldFileList, 'filereadable(fnamemodify(v:val, ":p"))')
    endif
    if len(l:oldFileList) == 1
        if l:oldFileCommand == 'IOldFiles'
            let l:ioldFile = matchstr(l:oldFileList[0], '/\zs[^/]*$')
            execute l:commandPrefix 'iolddocs /' . l:ioldFile . '/'
        else
            execute l:commandPrefix 'find' fnameescape(l:oldFileList[0])
        endif
        return
    else  " Present numbered list of found files
        call <SID>PrintFileList(a:bang, l:oldFileList, ':' . a:mode . l:oldFileCommand . a:bang . ' ' . a:pattern)
        return
    endif
endfunction
"}}}
function! find_file#Fasd(mode, pattern, command) abort  "{{{
    " Use `fasd` to find files/directories and lcd to them
    let l:fasdOptions = '-lR'
    let l:fasdOptions .= a:command ==# 'FasdAll' ? 'a' :
                \ a:command ==# 'FasdFiles' ? 'f' : 'd'
    let l:commandPrefix = <SID>ParseMode(a:mode)
    if a:pattern =~# '\d$'
        " A number, n, at the end of the search string selects the nth found
        " file.
        let l:pattern = matchstr(a:pattern, '.\{-}\ze\d*$')
        if l:pattern !=# ''  " If there is a pattern, construct file list and choose nth
            let l:index = matchstr(a:pattern, '\d*$')
            let l:files = split(system('fasd ' . l:fasdOptions . ' ' . l:pattern), '\n')
            call filter(l:files, 'v:val !~ "Dropbox\/"')
            try
                execute l:commandPrefix 'edit' fnameescape(l:files[l:index - 1])
                if a:command ==# 'FasdDirs'
                    " silent execute '!fasd -A' fnameescape(l:files[l:index - 1])
                    lcd %
                else
                    lcd %:p:h
                endif
                " redraw
                return
            catch /E684/  " Index out of range: assume number is part of filename
            endtry
        endif
    elseif a:pattern[-1:] =~# '*'
        " A '*' at the end will create a qflist with all found items
        let l:pattern = a:pattern[:-2]
        let l:files = split(system('fasd ' . l:fasdOptions . ' ' . l:pattern), '\n')
        call filter(l:files, 'v:val !~ "Dropbox\/"')
        let l:qflist = map(l:files, '{"filename": v:val}')
        call setqflist(l:qflist)
            call setqflist([], 'a', {'title': 'FASD List'})
        copen
        return
    endif
    " Present numbered list of found files
    let l:files = split(system('fasd ' . l:fasdOptions . ' ' . a:pattern), '\n')
    call filter(l:files, 'v:val !~ "Dropbox\/"')
    if len(l:files) == 1
        let l:file = fnameescape(l:files[0])
        execute l:commandPrefix 'find' l:file
        if isdirectory(l:file)
            " silent execute '!fasd -A' l:file
            lcd %
        else
           lcd %:p:h
        endif
        return
    else
        call <SID>PrintFileList('', l:files, ':' . a:mode . a:command . ' ' . a:pattern)
        return
    endif
endfunction
"}}}
