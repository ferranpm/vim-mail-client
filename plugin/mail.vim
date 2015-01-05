if exists('g:mail_netrc') && exists('g:mail_netrc_machine')
    call mail#ParseNetrc(g:mail_netrc, g:mail_netrc_machine)
endif
if !exists('g:mail_folder')      | let g:mail_folder      = "~/.vim/mail" | endif
if !exists('g:mail_imap_ssl')    | let g:mail_imap_ssl    = 1             | endif

command! -nargs=0 SMTPNew  call smtp#New()
command! -nargs=0 SMTPSend call smtp#Send('%')

command! -nargs=0 Mail if !mail#GotoBuffer('MAIL') | call imap#ShowFolders("") | endif
