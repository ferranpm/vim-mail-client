function mail#GotoBuffer()
    if bufexists('MAIL')
        setlocal modifiable
        let switchbuf=&switchbuf
        set switchbuf=useopen
        vertical sbuffer MAIL
        normal ggdG
        execute 'set switchbuf='.switchbuf
    else
        new
        file MAIL
    endif
endfunction
