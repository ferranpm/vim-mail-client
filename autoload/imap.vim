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
    nnoremap <buffer> <silent> rh :call imap#RefreshHeaders(b:mail_folder)<cr>:call imap#ListHeaders(b:mail_folder)<cr>
    nnoremap <buffer> <silent> rf :call imap#RefreshFolders(b:mail_folder)<cr>:call imap#ListFolders(b:mail_folder)<cr>
    nnoremap <buffer> <silent> b :call imap#BackFolder(b:mail_folder)<cr>
endfunction

function! imap#CreateIfNecessary(folder)
    let local_path = expand(g:mail_folder.'/'.a:folder)
    if !isdirectory(local_path)
        call mkdir(local_path, "p")
    endif
endfunction

function! imap#RefreshHeaders(folder)
    call imap#CreateIfNecessary(a:folder)
    let file_path = expand(g:mail_folder.'/'.a:folder).'/mail'
    let list = imap#FolderUIDs(a:folder)
    let request = imap#CurlRequest(a:folder, "FETCH ".join(list, ',')." ALL")
    let lines = filter(request, 'v:val =~# "^\* \\d\\+ FETCH"')
    call writefile(lines, file_path)
    return lines
endfunction

function! imap#RefreshFolders(folder)
    call imap#CreateIfNecessary(a:folder)
    let file_path = expand(g:mail_folder.'/'.a:folder).'/folder'
    let lines = filter(imap#CurlRequest(a:folder, ""), 'v:val =~# "^\* LIST "')
    call map(lines, 'substitute(v:val, "^\\* LIST (.*) \"/\" \"\\(.*\\)\"", "\\1", "")')
    call writefile(lines, file_path)
    return lines
endfunction

function! imap#ListHeaders(folder)
    let file_path = expand(g:mail_folder.'/'.a:folder).'/mail'
    if filereadable(file_path)
        let lines = readfile(file_path)
    else
        let lines = imap#RefreshHeaders(a:folder)
    endif
    call mail#GotoBuffer()
    let b:mail_folder = a:folder
    setlocal modifiable
    normal ggdG
    call append(0, lines)
    normal G
    setlocal nomodifiable
    setlocal nomodified
    call imap#BasicMappings()
    nnoremap <buffer> <silent> <cr> :call imap#Mail(b:mail_folder, split(getline('.'))[1])<cr>
endfunction

function! imap#ListFolders(folder)
    let file_path = expand(g:mail_folder.'/'.a:folder).'/folder'
    if filereadable(file_path)
        let lines = readfile(file_path)
    else
        let lines = imap#RefreshFolders(a:folder)
    endif
    call mail#GotoBuffer()
    let b:mail_folder = a:folder
    setlocal modifiable
    normal ggdG
    call append(0, lines)
    normal gg
    setlocal nomodified
    setlocal nomodifiable
    call imap#BasicMappings()
    nnoremap <buffer> <silent> l :call imap#ListFolders(b:mail_folder.getline('.'))<cr>
    nnoremap <buffer> <silent> <cr> :call imap#ListHeaders(b:mail_folder.getline('.'))<cr>
endfunction

function! imap#BackFolder(folder)
    let list = split(a:folder, '/')
    call remove(list, len(list) - 1)
    call imap#ListFolders(join(list, '/'))
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
