function! smtp#CheckFields()
    call mail#CheckField('g:mail_smtp_server', '')
    call mail#CheckField('g:mail_smtp_port'  , 'g:mail_smtp_server')
    call mail#CheckField('g:mail_address'    , 'g:mail_smtp_server')
    call mail#CheckField('g:mail_password'   , 'g:mail_smtp_server')
endfunction

function! smtp#NewBuffer()
    call mail#CreateIfNecessary('Sent')
    let filename = mail#GetLocalFolder('Sent').'/'.localtime().'.eml'
    execute 'split '.filename
    let b:mail_attachments = []
    nnoremap <buffer> <silent> <C-s> :call smtp#SendWrapper()<cr>
    nnoremap <buffer> <silent> <C-a> :call smtp#AttachWrapper()<cr>
    setlocal statusline=%#StatusLineNC#<C-s>%#StatusLine#:\ Send\ %#StatusLineNC#<C-a>%#StatusLine#:\ Attach\ File%=Attachments:%{string(b:mail_attachments)}
endfunction

function! smtp#New()
    call inputsave()

    " Get recipients
    let mail_to = []
    let inp = input("To: ")
    while inp != ""
        call add(mail_to, inp)
        let inp = input("To: ")
    endwhile

    let mail_subject = input("Subject: ")

    call inputrestore()

    call smtp#NewBuffer()
    setlocal filetype=mail

    call mail#CheckField('g:mail_smtp_server', '')
    call mail#CheckField('g:mail_address'    , 'g:mail_smtp_server')
    call setline(1, "From: <".g:mail_address.">")
    call setline(2, "To: <".join(mail_to, ">, <").">")
    call setline(3, "Subject: ".mail_subject)
    call setline(4, "")
    call setline(5, "")
    normal! G
endfunction

function! smtp#Reply(filename)
    ruby reply
    bwipeout
    call smtp#NewBuffer()
    call append(0, lines)
    normal! gg}O
endfunction

function! smtp#AttachWrapper()
    call inputsave()
    let file = input("File: ", "", "file")
    call inputrestore()
    if match(file, "^$") != 0
        call smtp#Attach(file)
    endif
endfunction

function! smtp#Attach(filename)
    call add(b:mail_attachments, expand(a:filename))
endfunction

function! smtp#SendWrapper()
    update
    call smtp#Send('%')
    bwipeout
endfunction

function! smtp#Send(filename)
    call smtp#CheckFields()
    ruby send
endfunction
