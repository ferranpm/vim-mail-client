function! imap#CurlRequest(path, request)
    let request = ""
    if a:request != ""
        let request = ' --request "'.a:request.'"'
    endif

    let path = join(filter(split(a:path, '/'), 'v:val != ""'), '/')
    let response = system('curl --verbose --ssl '.
                \' --url "'.g:mail_imap_server.'/'.path.'" '.
                \ '--user '.g:mail_address.':'.g:mail_password.' '.
                \ request)
    let splited = split(response, '\n')
    let filtered = filter(splited, 'v:val =~ "^< "')
    return map(filtered, 'substitute(v:val, "\\(^< \\|\\r\\)", "", "g")')
endfunction

function! imap#FolderUIDs(folder)
    let list = split(join(filter(imap#CurlRequest(a:folder, "SEARCH ALL"), 'v:val =~# "^\\* SEARCH "'), ""), " ")
    call remove(list, 0, 1)
    call map(list, 'str2nr(v:val)')
    call reverse(list)
    return list
endfunction

function! imap#BasicMappings()
    nnoremap <buffer> <silent> rh :call imap#RefreshHeaders(b:mail_folder)<cr>:call imap#ShowHeaders(b:mail_folder)<cr>
    nnoremap <buffer> <silent> rf :call imap#RefreshFolders(b:mail_folder)<cr>:call imap#ShowFolders(b:mail_folder)<cr>
    nnoremap <buffer> <silent> b :call imap#ShowFolders(imap#BackFolder(b:mail_folder))<cr>
endfunction

function! imap#CreateIfNecessary(folder)
    let local_path = mail#GetLocalFolder(a:folder)
    if !isdirectory(local_path)
        call mkdir(local_path, "p")
    endif
endfunction

function! imap#ParseHeaders(headers)
    let uid_match = '\(\d\+\)'
    let date_match = '[^"]\+'
    let subject_match = '\([^"]\+\)'
    let from_match = '\%("\|\%(NIL \)\+"\)\([^"]\+\)"[^)]\+'
    let match = '^\* '.uid_match.' FETCH (ENVELOPE ("'.date_match.'" \%(NIL\|"'.subject_match.'"\) (('.from_match.')) .*'
    let dictionaries = []
    for header in a:headers
        let matches = matchlist(header, match)
        let dict = {
                    \ 'uid': get(matches, 1, 0),
                    \ 'subject': get(matches, 2, header),
                    \ 'from': get(matches, 3, "")
                    \ }
        call add(dictionaries, dict)
    endfor
    return dictionaries
endfunction

function! imap#RefreshHeaders(folder)
    call imap#CreateIfNecessary(a:folder)
    let file_path = mail#GetLocalFolder(a:folder).'/mail'
    let list = imap#FolderUIDs(a:folder)
    let request = imap#CurlRequest(a:folder, "FETCH ".join(list, ',')." ALL")
    let lines = filter(request, 'v:val =~# "^\* \\d\\+ FETCH"')
    call writefile(lines, file_path)
    return lines
endfunction

function! imap#RefreshFolders(folder)
    call imap#CreateIfNecessary(a:folder)
    let file_path = mail#GetLocalFolder(a:folder).'/folder'
    let lines = filter(imap#CurlRequest(a:folder, ""), 'v:val =~# "^\* LIST "')
    call writefile(lines, file_path)
    return lines
endfunction

function! imap#RefreshRecursive(folder)
    call imap#RefreshHeaders(a:folder)
    for folder in imap#RefreshFolders(a:folder)
        call imap#RefreshRecursive(a:folder.'/'.folder)
    endfor
endfunction

function! imap#ListHeaders(folder)
    let file_path = mail#GetLocalFolder(a:folder).'/mail'
    if filereadable(file_path)
        let lines = readfile(file_path)
    else
        let lines = imap#RefreshHeaders(a:folder)
    endif
    let headers = imap#ParseHeaders(lines)
    let lines = []
    for header in headers
        let uid = header['uid']
        let subject = substitute(header['subject'], "$", "                                                            ", "")
        let from = header['from']
        call add(lines, printf("*%.4s*\t<>%.60s<>\t$%s$", uid, subject, from))
    endfor
    return lines
endfunction

function! imap#ListFolders(folder)
    let file_path = mail#GetLocalFolder(a:folder).'/folder'
    if filereadable(file_path)
        let lines = readfile(file_path)
    else
        let lines = imap#RefreshFolders(a:folder)
    endif
    call map(lines, 'substitute(v:val, "^\\* LIST (.*) \"/\" \"\\(.*\\)\"", "\\1", "")')
    return lines
endfunction

function! imap#ShowHeaders(folder)
    let lines = reverse(imap#ListHeaders(a:folder))
    call mail#GotoBuffer()
    setlocal filetype=mailheaders
    let b:mail_folder = a:folder
    setlocal modifiable
    normal ggdG
    call append(0, lines)
    normal gg
    setlocal nomodifiable
    setlocal nomodified
    call imap#BasicMappings()
    nnoremap <buffer> <silent> <cr> :call imap#Mail(b:mail_folder, matchstr(getline('.'), '^\*\zs\d\+'))<cr>
endfunction

function! imap#ShowFolders(folder)
    let lines = imap#ListFolders(a:folder)
    call mail#GotoBuffer()
    let b:mail_folder = a:folder
    setlocal filetype=mailfolders
    setlocal modifiable
    normal ggdG
    call append(0, lines)
    normal gg
    setlocal nomodified
    setlocal nomodifiable
    call imap#BasicMappings()
    nnoremap <buffer> <silent> l :call imap#ShowFolders(b:mail_folder.getline('.'))<cr>
    nnoremap <buffer> <silent> <cr> :call imap#ShowHeaders(b:mail_folder.getline('.'))<cr>
endfunction

function! imap#BackFolder(folder)
    let list = split(a:folder, '/')
    call remove(list, len(list) - 1)
    return join(list, '/')
endfunction

function! imap#Mail(folder, uid)
    new
    let b:mail_folder = a:folder
    let request = imap#CurlRequest(a:folder, 'FETCH '.a:uid.' (BODY[HEADER.FIELDS (FROM TO SUBJECT DATE)] BODY[TEXT])')
    call filter(request, 'v:val !~# "\\(^\\* \\|^\\a\\d\\+ OK \\)"')
    let header = remove(request, -7, -1)
    call remove(header, 0)
    call remove(header, -2, -1)
    call append(0, header)
    call append(line('$'), request)
    normal gg
    nnoremap <buffer> <silent> r :call smtp#Reply()<cr>
    setlocal filetype=mail
    setlocal foldmethod=syntax foldlevel=0
    setlocal nomodified
    setlocal nomodifiable
endfunction
