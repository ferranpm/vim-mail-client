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
    return expand(g:mail_folder.'/'.sha256(g:mail_address).'/'.a:folder)
endfunction

function! mail#CheckField(field)
    call inputsave()
    if !exists(a:field)
        execute 'let '.a:field.' = input("'.a:field.': ")'
    endif
    call inputrestore()
endfunction
