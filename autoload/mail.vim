function! mail#GotoBuffer()
    if bufexists('MAIL')
        let switchbuf=&switchbuf
        set switchbuf=useopen
        vertical sbuffer MAIL
        execute 'set switchbuf='.switchbuf
    else
        new
        file MAIL
    endif
endfunction

" Returns a dictionary containing the alias of the address (if present) and
" the email address
function! mail#ParseAddress(address)
    return {'alias': matchstr(a:address, '.*\ze<.*>'), 'address': matchstr(a:address, '<\zs.*\ze>')}
endfunction

function! mail#Parse(filename)
    let lines = readfile(expand(a:filename))
    let to = []
    let from = {}
    for line in lines
        if match(line, '^From: .*$') == 0
            let from = mail#ParseAddress(matchlist(line, '^From: \(.*\)$')[1])
        endif
        if match(line, '^To: \(.*,\?\)*$') == 0
            for item in split(matchlist(line, '^To: \(.*\)$')[1], ',')
                call add(to, mail#ParseAddress(item))
            endfor
        endif
    endfor
    return {'from': from, 'to': to}
endfunction

function! mail#GetLocalFolder(folder)
    return expand(g:mail_folder.'/'.sha256(g:mail_address).'/'.a:folder)
endfunction
