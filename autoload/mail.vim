function! mail#GotoBuffer(buffer)
    if bufexists(a:buffer)
        let switchbuf=&switchbuf
        set switchbuf=useopen
        execute 'vertical sbuffer '.a:buffer
        execute 'set switchbuf='.switchbuf
        return 1
    else
        new
        execute 'file '.a:buffer
        return 0
    endif
endfunction

" Returns a dictionary containing the alias of the address (if present) and
" the email address
function! mail#ParseAddress(address)
    return {'alias': matchstr(a:address, '.*\ze<.*>'), 'address': matchstr(a:address, '<\zs.*\ze>')}
endfunction

function! mail#GetLocalFolder(folder)
    if exists('g:mail_netrc')
        call mail#ParseNetrc(g:mail_netrc, 'g:mail_imap_server')
    endif
    if exists('g:mail_address')
        return expand(g:mail_folder.'/'.sha256(g:mail_address).'/'.a:folder)
    endif
    return ""
endfunction

function! mail#ParseNetrc(filename, machine)
ruby << EOF
    require 'netrc'
    filename = VIM::evaluate('expand(a:filename)')
    machine = VIM::evaluate(VIM::evaluate('a:machine'))
    netrc = Netrc.read(if filename.length > 0 then filename end)
    user, password = netrc[machine]
    VIM::command("let g:mail_address = \"#{user}\"")
    VIM::command("let g:mail_password = \"#{password}\"")
EOF
endfunction

function! mail#CheckField(field, machine)
    if exists('g:mail_netrc') && exists(a:machine)
        call mail#ParseNetrc(g:mail_netrc, a:machine)
    endif
    call inputsave()
    if !exists(a:field)
        execute 'let '.a:field.' = input("'.a:field.': ")'
    endif
    call inputrestore()
endfunction
