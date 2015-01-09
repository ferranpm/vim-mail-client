if !exists('g:mail_folder')      | let g:mail_folder      = "~/.vim/mail" | endif
if !exists('g:mail_imap_ssl')    | let g:mail_imap_ssl    = 1             | endif
if !exists('g:mail_tmp_file')    | let g:mail_tmp_file    = "/tmp/vim_mail" | endif

if !filereadable(g:mail_tmp_file)
    let g:mail_visited = []
else
    let g:mail_visited = readfile(g:mail_tmp_file)
endif

command! -nargs=0 WriteMail  call smtp#New()
command! -nargs=0 Mail if !mail#GotoBuffer('MAIL', 'tabe') | call imap#ShowHeaders("INBOX") | endif
