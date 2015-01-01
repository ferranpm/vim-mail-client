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

function! imap#ListHeaders(folder, ...)
    let list = imap#FolderUIDs(a:folder)
    if a:0 == 2 | call remove(list, a:1 + a:2, -1) | endif
    if a:0 > 1 && a:1 > 0 | call remove(list, 0, a:1 - 1) | endif
    call mail#GotoBuffer()
    let b:mail_folder = a:folder
    normal ggdG
    let request = imap#CurlRequest(a:folder, "FETCH ".join(list, ',')." ALL")
    call append(0, filter(request, 'v:val =~# "^\* \\d\\+ FETCH"'))
    normal G
    nnoremap <buffer> <silent> <cr> :call imap#Mail(b:mail_folder, split(getline('.'))[1])<cr>
    nnoremap <buffer> <silent> b :call imap#BackFolder(b:mail_folder)<cr>
    setlocal nomodified
    setlocal nomodifiable
endfunction

function! imap#ListFolders(folder)
    call mail#GotoBuffer()
    let b:mail_folder = a:folder
    normal ggdG
    call append(0, filter(imap#CurlRequest(a:folder, ""), 'v:val =~# "^\* LIST "'))
    normal gg
    nnoremap <buffer> <silent> l :call imap#ListFolders(b:mail_folder.split(split(getline('.'))[-1], '"')[0])<cr>
    nnoremap <buffer> <silent> b :call imap#BackFolder(b:mail_folder)<cr>
    nnoremap <buffer> <silent> <cr> :call imap#ListHeaders(b:mail_folder.split(split(getline('.'))[-1], '"')[0]."/", 0, 10)<cr>
    setlocal nomodified
    setlocal nomodifiable
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
