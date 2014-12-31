if !exists('g:mail_address')     | let g:mail_address     = ""            | endif
if !exists('g:mail_password')    | let g:mail_password    = ""            | endif
if !exists('g:mail_smtp_server') | let g:mail_smtp_server = ""            | endif
if !exists('g:mail_imap_server') | let g:mail_imap_server = ""            | endif
if !exists('g:mail_folder')      | let g:mail_folder      = "~/.vim-mail" | endif

command! -nargs=0 SMTPNew  call smtp#New()
command! -nargs=0 SMTPSend call smtp#Send('%')

command! -nargs=0 Mail call imap#ListFolders("")
