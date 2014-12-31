function! smtp#New()
    let filename = '/tmp/vim_mail_'.localtime().'.mail'
    execute 'split '.filename

    call inputsave()

    " Get recipients
    let mail_to = []
    let inp = "hola"
    while inp != ""
        let inp = input("To: ")
        if inp != ""
            call add(mail_to, inp)
        endif
    endwhile

    let mail_subject = input("Subject: ")

    call inputrestore()

    setlocal filetype=mail
    call setline(1, "From: <".g:mail_address.">")
    call setline(2, "To: <".join(mail_to, ">,<").">")
    call setline(3, "Subject: ".mail_subject)
    call setline(4, "")
    call setline(5, "")
    normal G
endfunction

function! smtp#Reply()
endfunction

function! smtp#Send(filename)
    let res = ""
    let info = mail#Parse(a:filename)
    for address in info['to']
        let res = res.system('curl --url "'.g:mail_smtp_server.'" '.
                    \ '--user "'.g:mail_address.':'.g:mail_password.'" '.
                    \ '--mail-from "'.g:mail_address.'" '.
                    \ '--mail-rcpt "'.address['address'].'" '.
                    \ '--upload-file "'.expand(a:filename).'" '.
                    \ '--ssl-reqd ')
    endfor
    echo res
endfunction
