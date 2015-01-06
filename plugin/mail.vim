if !exists('g:mail_folder')      | let g:mail_folder      = "~/.vim/mail" | endif
if !exists('g:mail_imap_ssl')    | let g:mail_imap_ssl    = 1             | endif

let g:mail_attachments = []

command! -nargs=0 SMTPNew  call smtp#New()
command! -nargs=1 -complete=file SMTPAttach call smtp#Attach(<q-args>)
command! -nargs=0 SMTPSend call smtp#Send('%')

command! -nargs=0 Mail if !mail#GotoBuffer('MAIL') | call imap#ShowFolders("") | endif
