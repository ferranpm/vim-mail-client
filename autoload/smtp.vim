function! smtp#New()
    let filename = '/tmp/vim_mail_'.localtime().'.mail'
    execute 'split '.filename

    call inputsave()

    " Get recipients
    let b:mail_to = []
    let inp = "hola"
    while inp != ""
        let inp = input("To: ")
        if inp != ""
            call add(b:mail_to, inp)
        endif
    endwhile

    let b:mail_subject = input("Subject: ")

    call inputrestore()

    setlocal filetype=mail
    call setline(1, "From: <".g:mail_address.">")
    call setline(2, "To: <".join(b:mail_to, ">,<").">")
    call setline(3, "Subject: ".b:mail_subject)
    call setline(4, "")
    call setline(5, "")
    normal G
endfunction

function! smtp#Reply()
endfunction

function! smtp#Send(filename, mail_to)
    let res = ""
    for address in a:mail_to
        let res = res.system('curl --url "'.g:mail_smtp_server.'" '.
                    \ '--user "'.g:mail_address.':'.g:mail_password.'" '.
                    \ '--mail-from "'.g:mail_address.'" '.
                    \ '--mail-rcpt "'.address.'" '.
                    \ '--upload-file "'.expand(a:filename).'" '.
                    \ '--ssl-reqd ')
    endfor
    echo res
endfunction
