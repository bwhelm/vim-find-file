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
            call filter(l:fileList, 'fnamemodify(v:val, ":t") !~? l:item[1:]')
        else
            call filter(l:fileList, 'fnamemodify(v:val, ":t") =~? l:item')
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
        split new  " Create a temporary window
        wincmd J   " Push to bottom, spanning full width
        let l:width = winwidth(0)  " Now read full width
        bwipeout  " Get rid of temporary window
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
            echohl Comment | echo '... [and ' . string(len(a:files) - l:height) . ' more] ...'
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
    " Take file glob and return list of matching files. Glob is taken from
    " g:findFilesGlobList, a list of wildcard patterns. Note that `glob`bing
    " and `map`ping are expensive, so save the filelist for reuse in the next
    " few seconds, assuming the file list won't change in that time; after
    " that, generate the list again.
    let l:patternList = split(a:patternString, ' ')
    if !exists('b:quickTime') || localtime() - b:quickTime > 20
        echohl Comment
        echo '(Re)creating filelist ...'
        echohl None
        let b:quickFiles = []
        " FIXME: Use `globpath()` instead!
        for item in g:findFilesGlobList
            let b:quickFiles += glob(item, 0, 1)
        endfor
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
    let l:originalWindow = win_getid()
    if a:pattern =~# '\d$'
        " A number, n, at the end of the search string selects the nth found
        " file.
        let l:pattern = matchstr(a:pattern, '.\{-}\ze\d*$')
        if l:pattern !=# ''
            let l:index = matchstr(a:pattern, '\d*$')
            let l:files = <SID>GetFilesFromPattern(l:pattern)
            try
                call win_gotoid(l:originalWindow)
                execute 'silent' l:commandPrefix 'edit' fnameescape(l:files[l:index - 1])
                redraw
                unlet b:quickTime
                unlet b:quickFiles
                return
            catch /E684/  " Index out of range: assume number is part of filename and fall through
            catch /E108/  " No such variabla: can't `unlet`, so return
                return
            endtry
        endif
    elseif a:pattern[-1:] ==# '*'
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
        call win_gotoid(l:originalWindow)
        execute 'silent' l:commandPrefix 'edit' fnameescape(l:files[0])
        return
    else
        call <SID>PrintFileList('', l:files, ':' . a:mode . 'FileFind ' . a:pattern)
        call win_gotoid(l:originalWindow)
        return
    endif
endfunction
"}}}
function! s:formatTerm(term) abort  "{{{
    if a:term =~# "^+"
        return '"^tags:.*' . a:term[1:] . '"'
    else
        return '"' . a:term . '"'
    endif
endfunction
"}}}
function! find_file#AndGrep(pattern, scope) abort  "{{{
    " Finds files having all of the terms in a:terms somewhere in their
    " contents. Can keep adding multiple search terms to narrow the search,
    " can select a file by number, or can send all files to quickfix list.
    let l:grepprog = executable('rg') ? 'rg --vimgrep --smart-case' : 'grep -il'
    let l:originalWindow = win_getid()
    let l:files = glob(a:scope, 0, 1)
    let l:patternList = split(a:pattern)
    if l:patternList[-1] =~ '\d\+'
        " A number, n, at the end of the string selects the nth found file.
        let l:index = remove(l:patternList, -1)
        if len(l:patternList) > 0
            for l:term in l:patternList
                let l:files = systemlist(l:grepprog . ' ' . <SID>formatTerm(l:term) . ' ' .
                        \ join(map(copy(l:files), {key, val -> '"' . val . '"'})))
            endfor
            call sort(l:files)
            try
                call win_gotoid(l:originalWindow)
                execute 'edit' fnameescape(l:files[l:index - 1])
                redraw
                return
            catch /E684/  " Index out of range: assume number is part of filename
                let l:patternList = split(a:pattern)
            endtry
        endif
    endif
    if l:patternList[-1][-1] ==# '*'
        " A '*' at the end will create a qflist with all found items
        let l:patternList[-1] = l:patternList[-1][:-2]  " Drop the '*'
        for l:term in l:patternList
            let l:files = systemlist(l:grepprog . ' ' . <SID>formatTerm(l:term) . ' ' .
                        \ join(map(copy(l:files), {key, val -> '"' . val . '"'})))
        endfor
        if len(l:files) > 0
            " Display QF list only if at least one file found; otherwise fall through
            call sort(l:files)
            let l:qflist = map(l:files, '{"filename": v:val}')
            call setqflist(l:qflist)
            call setqflist([], 'a', {'title': 'AndGrep: ' . a:pattern[:-2]})
            call win_gotoid(l:originalWindow)
            copen
            return
        endif
    endif
    for l:term in l:patternList
        let l:files = systemlist(l:grepprog . ' ' . <SID>formatTerm(l:term) . ' ' .
                    \ join(map(copy(l:files), {key, val -> '"' . val . '"'})))
    endfor
    call sort(l:files)
    if len(l:files) == 1  " If only one, open it!
        call win_gotoid(l:originalWindow)
        execute 'edit' fnameescape(l:files[0])
    else
        " Present numbered list of found files
        call <SID>PrintFileList('', l:files, ':AndGrep ' . a:pattern)
        call win_gotoid(l:originalWindow)
    endif
    return
endfunction
"}}}
function! s:GetIOldDocsList() abort  "{{{
    redir => l:ioldString
    silent execute 'iolddocs'
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
    let l:originalWindow = win_getid()
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
                    call win_gotoid(l:originalWindow)
                    execute l:commandPrefix 'iolddocs' . a:bang . ' /' . l:ioldFile . '/'
                catch
                    echohl WarningMsg
                    echo 'Cannot open file; removing from old files list.'
                    echohl None
                    call win_gotoid(l:originalWindow)
                    execute 'iolddocs! /' . l:ioldFile . '/'
                endtry
                return
            endif  " If number is larger, treat number as part of pattern
        else  " If not IOldFiles
            let l:oldFileList = <SID>FilterFileList(copy(v:oldfiles), split(l:pattern, ' '))
            call filter(l:oldFileList, 'filereadable(fnamemodify(v:val, ":p"))')
            if l:number <= len(l:oldFileList)
                call win_gotoid(l:originalWindow)
                execute 'silent' l:commandPrefix 'edit' fnameescape(l:oldFileList[l:number - 1])
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
            call win_gotoid(l:originalWindow)
            execute l:commandPrefix 'iolddocs /' . l:ioldFile . '/'
        else
            call win_gotoid(l:originalWindow)
            execute 'silent' l:commandPrefix 'edit' fnameescape(l:oldFileList[0])
        endif
        return
    else  " Present numbered list of found files
        call <SID>PrintFileList(a:bang, l:oldFileList, ':' . a:mode . l:oldFileCommand . a:bang . ' ' . a:pattern)
        call win_gotoid(l:originalWindow)
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
    let l:originalWindow = win_getid()
    if a:pattern =~# '\d$'
        " A number, n, at the end of the search string selects the nth found
        " file.
        let l:pattern = matchstr(a:pattern, '.\{-}\ze\d*$')
        if l:pattern !=# ''  " If there is a pattern, construct file list and choose nth
            let l:index = matchstr(a:pattern, '\d*$')
            let l:files = split(system('fasd ' . l:fasdOptions . ' ' . l:pattern), '\n')
            " call filter(l:files, 'v:val !~ "Dropbox\/"')
            try
                call win_gotoid(l:originalWindow)
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
        " call filter(l:files, 'v:val !~ "Dropbox\/"')
        let l:qflist = map(l:files, '{"filename": v:val}')
        call setqflist(l:qflist)
        call setqflist([], 'a', {'title': 'FASD List'})
        call win_gotoid(l:originalWindow)
        copen
        return
    endif
    " Present numbered list of found files
    let l:files = split(system('fasd ' . l:fasdOptions . ' ' . a:pattern), '\n')
    " call filter(l:files, 'v:val !~ "Dropbox\/"')
    if len(l:files) == 1
        let l:file = fnameescape(l:files[0])
        call win_gotoid(l:originalWindow)
        execute 'silent' l:commandPrefix 'edit' l:file
        if isdirectory(l:file)
            " silent execute '!fasd -A' l:file
            lcd %
        else
            lcd %:p:h
        endif
        return
    else
        call <SID>PrintFileList('', l:files, ':' . a:mode . a:command . ' ' . a:pattern)
        call win_gotoid(l:originalWindow)
        return
    endif
endfunction
"}}}
