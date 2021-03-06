function! imap#BasicMappings()
    nnoremap <buffer> <silent> R  :call imap#UpdateHeaders(b:mail_folder)<cr>:call imap#ShowHeaders(b:mail_folder)<cr>
    nnoremap <buffer> <silent> rf :call imap#RefreshFolders(b:mail_folder)<cr>:call imap#ShowFolders(b:mail_folder)<cr>
    nnoremap <buffer> <silent> b :call imap#ShowFolders(imap#BackFolder(b:mail_folder))<cr>
    return '%#StatusLineNC#R%#StatusLine#:\ Update\ mail\ %#StatusLineNC#rf%#StatusLine#:\ Refresh\ folders\ %#StatusLineNC#b%#StatusLine#:\ Go\ back\ folder'
endfunction

function! imap#CheckFields()
    call mail#CheckField('g:mail_imap_server', '')
    call mail#CheckField('g:mail_imap_port'  , 'g:mail_imap_server')
    call mail#CheckField('g:mail_address'    , 'g:mail_imap_server')
    call mail#CheckField('g:mail_password'   , 'g:mail_imap_server')
endfunction

function! imap#BackFolder(folder)
    let list = split(a:folder, '/')
    if len(list) > 0
        call remove(list, len(list) - 1)
    endif
    return join(list, '/')
endfunction

function! imap#UpdateHeaders(folder)
    call imap#ListHeaders(a:folder)
    let file_path = mail#GetLocalFolder(a:folder).'/mail'
    let lines = []
    ruby update_headers
    if len(lines) > 0
         call writefile(lines, file_path)
    endif
    return lines
endfunction

function! imap#RefreshHeaders(folder)
    call imap#CheckFields()
    call mail#CreateIfNecessary(a:folder)
    let file_path = mail#GetLocalFolder(a:folder).'/mail'
    let lines = []
    ruby refresh_headers
    if len(lines) > 0
        call writefile(lines, file_path)
    endif
    return lines
endfunction

function! imap#RefreshFolders(folder)
    call imap#CheckFields()
    call mail#CreateIfNecessary(a:folder)
    let file_path = mail#GetLocalFolder(a:folder).'/folder'
    let lines = []
    ruby refresh_folders
    if len(lines) > 0
        call writefile(lines, file_path)
    endif
    return lines
endfunction

function! imap#RefreshRecursive(folder)
    echo "Refreshing: ".a:folder
    call imap#RefreshHeaders(a:folder)
    for folder in imap#RefreshFolders(a:folder)
        call imap#RefreshRecursive(a:folder.'/'.split(folder, '"')[-1])
    endfor
endfunction

function! imap#ListHeaders(folder)
    let file_path = mail#GetLocalFolder(a:folder).'/mail'
    if filereadable(file_path)
        let lines = readfile(file_path)
    else
        let lines = imap#RefreshHeaders(a:folder)
    endif
    return lines
endfunction

function! imap#ListFolders(folder)
    let file_path = mail#GetLocalFolder(a:folder).'/folder'
    if filereadable(file_path)
        let lines = readfile(file_path)
    else
        let lines = imap#RefreshFolders(a:folder)
    endif
    return lines
endfunction

function! imap#ShowHeaders(folder)
    if index(g:mail_visited, a:folder) == -1
        call imap#RefreshHeaders(a:folder)
        call add(g:mail_visited, a:folder)
        call writefile(g:mail_visited, g:mail_tmp_file)
    end
    call mail#GotoBuffer('MAIL', 'tabe')
    setlocal filetype=mailheaders
    let b:mail_folder = a:folder
    setlocal modifiable
    normal! ggdG
    call append(0, imap#ListHeaders(a:folder))
    normal! gg
    setlocal nomodifiable
    setlocal nomodified
    nnoremap <buffer> <silent> d :call imap#DeleteMail(b:mail_folder, matchstr(getline('.'), '^\*\zs\d\+'))<cr>:call imap#ShowHeaders(b:mail_folder)<cr>
    nnoremap <buffer> <silent> l :call imap#ShowMail(b:mail_folder, matchstr(getline('.'), '^\*\zs\d\+'))<cr>
    nnoremap <buffer> <silent> <cr> :call imap#ShowMail(b:mail_folder, matchstr(getline('.'), '^\*\zs\d\+'))<cr>
    execute 'setlocal statusline=%#StatusLineNC#<cr>/l%#StatusLine#:\ Open\ Mail\ %#StatusLineNC#d%#StatusLine#:\ Delete\ Mail\ '.imap#BasicMappings()
endfunction

function! imap#ShowFolders(folder)
    let lines = imap#ListFolders(a:folder)
    call mail#GotoBuffer('MAIL', 'tabe')
    let b:mail_folder = a:folder
    setlocal filetype=mailfolders
    setlocal modifiable
    normal! ggdG
    call append(0, lines)
    normal! gg
    setlocal nomodified
    setlocal nomodifiable
    nnoremap <buffer> <silent> c    :call imap#ShowFolders(b:mail_folder.getline('.'))<cr>
    nnoremap <buffer> <silent> l    :call imap#ShowHeaders(b:mail_folder.getline('.'))<cr>
    nnoremap <buffer> <silent> <cr> :call imap#ShowHeaders(b:mail_folder.getline('.'))<cr>
    execute 'setlocal statusline=%#StatusLineNC#<cr>/l%#StatusLine#:\ Show\ Mails\ %#StatusLineNC#c%#StatusLine#:\ Show\ Folders\ '.imap#BasicMappings()
endfunction

function! imap#ShowMail(folder, uid)
    let file_path = mail#GetLocalFolder(a:folder).'/'.a:uid.'.eml'
    call mail#GotoBuffer(string(a:uid), 'new')
    let b:mail_folder = a:folder
    let b:mail_uid = a:uid
    let b:mail_file_path = file_path
    if filereadable(file_path)
        let lines = readfile(file_path)
    else
        ruby get_mail
        if len(lines) > 0
            call writefile(lines, file_path)
        endif
    endif
    ruby parse_mail
    setlocal modifiable
    normal! ggdG
    call append(0, lines)
    normal! gg
    execute 'setlocal statusline=%#StatusLineNC#r%#StatusLine#:\ Reply\ %#StatusLineNC#s%#StatusLine#:\ Save\ Attachments\ %#StatusLineNC#a%#StatusLine#:\ Archive%='.attachments.'\ attachments'
    nnoremap <buffer> <silent> s :call imap#SaveAttachments(b:mail_file_path)<cr>
    nnoremap <buffer> <silent> r :call smtp#Reply(b:mail_file_path)<cr>
    nnoremap <buffer> <silent> a :call imap#ArchiveWrapper(b:mail_folder, b:mail_uid)<cr>
    setlocal filetype=mail
    setlocal foldmethod=syntax
    setlocal nomodified
    setlocal nomodifiable
endfunction

function! imap#Archive(folder_orig, folder_dest, uid)
    ruby archive
    let orig = mail#GetLocalFolder(a:folder_orig).'/'.a:uid.'.eml'
    call delete(orig)
    call imap#RefreshHeaders(b:mail_folder)
endfunction

function! imap#ArchiveWrapper(folder, uid)
    call inputsave()
    let dest = input("Folder: ", "")
    call inputrestore()
    if dest =~ "^$"
        return
    endif
    call imap#Archive(a:folder, dest, a:uid)
    bwipeout
    call imap#ShowHeaders(b:mail_folder)
endfunction

function! imap#SaveAttachments(filename)
    call inputsave()
    let path = input("Directory: ", "", "dir")
    call inputrestore()
    if match(path, "^$") == 0
        return
    endif
    ruby save_attachments
endfunction

function! imap#DeleteMail(folder, uid)
    ruby delete_mail
    let file_path = mail#GetLocalFolder(a:folder).'/'.a:uid.'.eml'
    if filewritable(file_path)
        call delete(file_path)
    endif
    let mail_path = mail#GetLocalFolder(a:folder).'/mail'
    let lines = readfile(mail_path)
    for line in lines
        echo line
        if match(line, "^\*".a:uid."\*") == 0
            call remove(lines, index(lines, line))
            call writefile(lines, mail_path)
            return
        endif
    endfor
endfunction
