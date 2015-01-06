if !exists('g:mail_folder')      | let g:mail_folder      = "~/.vim/mail" | endif
if !exists('g:mail_imap_ssl')    | let g:mail_imap_ssl    = 1             | endif

command! -nargs=0 WriteMail  call smtp#New()
command! -nargs=0 Mail if !mail#GotoBuffer('MAIL') | call imap#ShowFolders("") | endif
