ruby require 'net/imap'; require 'mail'

ruby << EOF
module Net
    class IMAP
        def self.vim_login
            address  = VIM::evaluate('g:mail_address')
            password = VIM::evaluate('g:mail_password')
            server   = VIM::evaluate('g:mail_imap_server')
            port     = VIM::evaluate('g:mail_imap_port').to_i
            ssl      = VIM::evaluate('g:mail_imap_ssl').to_i == 1 ? true : false
            imap     = Net::IMAP.new(server, port, ssl)
            imap.login(address, password)
            return imap
        end

        def vim_logout
            self.logout
            self.disconnect
        end
    end
end
EOF

function! imap#BasicMappings()
    nnoremap <buffer> <silent> R  :call imap#UpdateNew(b:mail_folder)<cr>:call imap#ShowHeaders(b:mail_folder)<cr>
    nnoremap <buffer> <silent> rf :call imap#RefreshFolders(b:mail_folder)<cr>:call imap#ShowFolders(b:mail_folder)<cr>
    nnoremap <buffer> <silent> b :call imap#ShowFolders(imap#BackFolder(b:mail_folder))<cr>
    return '%#StatusLineNC#R%#StatusLine#:\ Update\ mail\ %#StatusLineNC#rf%#StatusLine#:\ Refresh\ folders\ %#StatusLineNC#b%#StatusLine#:\ Go\ back\ folder'
endfunction

function! imap#CreateIfNecessary(folder)
    let local_path = mail#GetLocalFolder(a:folder)
    if !isdirectory(local_path)
        call mkdir(local_path, "p")
    endif
endfunction

function! imap#CheckFields()
    call mail#CheckField('g:mail_imap_server', '')
    call mail#CheckField('g:mail_imap_port'  , 'g:mail_imap_server')
    call mail#CheckField('g:mail_address'    , 'g:mail_imap_server')
    call mail#CheckField('g:mail_password'   , 'g:mail_imap_server')
endfunction

function! imap#BackFolder(folder)
    let list = split(a:folder, '/')
    if len(list) > 0
        call remove(list, len(list) - 1)
    endif
    return join(list, '/')
endfunction

ruby << EOF
def format_message_header message
    envelope = message.attr["ENVELOPE"]
    uid = message.attr["UID"]
    name = envelope.from[0].name || ('<' << (envelope.from[0].mailbox || '') << '@' << (envelope.from[0].host || '') << '>')
    name = '$' + Mail::Encodings.value_decode(name) + '$                             '
    name.slice!(30..name.length)
    subject = envelope.subject || ''
    subject = Mail::Encodings.value_decode(subject)
    "*#{uid}*\t$#{name}$\t<>#{subject}<>"
end
EOF

function! imap#RefreshHeaders(folder)
    call imap#CheckFields()
    call imap#CreateIfNecessary(a:folder)
    let file_path = mail#GetLocalFolder(a:folder).'/mail'
    let lines = []
ruby << EOF
    folder = VIM::evaluate('a:folder')
    imap   = Net::IMAP.vim_login
    imap.select(folder)
    lines  = []
    imap.fetch(1..-1, ["ENVELOPE", "UID"]).each do |item|
        lines << format_message_header(item)
    end
    VIM::command("let lines = #{lines.reverse}")
    imap.vim_logout
EOF
    if len(lines) > 0
        call writefile(lines, file_path)
    endif
    return lines
endfunction

function! imap#RefreshFolders(folder)
    call imap#CheckFields()
    call imap#CreateIfNecessary(a:folder)
    let file_path = mail#GetLocalFolder(a:folder).'/folder'
    let lines = []
ruby << EOF
    imap = Net::IMAP.vim_login
    folder = VIM::evaluate('a:folder')
    lines = []
    imap.list(folder, "*").each do |f|
        lines << f.name
    end
    imap.vim_logout
    VIM::command("let lines = #{lines}")
EOF
    if len(lines) > 0
        call writefile(lines, file_path)
    endif
    return lines
endfunction

function! imap#RefreshRecursive(folder)
    echo "Refreshing: ".a:folder
    call imap#RefreshHeaders(a:folder)
    for folder in imap#RefreshFolders(a:folder)
        call imap#RefreshRecursive(a:folder.'/'.split(folder, '"')[-1])
    endfor
endfunction

function! imap#ListHeaders(folder)
    let file_path = mail#GetLocalFolder(a:folder).'/mail'
    if filereadable(file_path)
        let lines = readfile(file_path)
    else
        let lines = imap#RefreshHeaders(a:folder)
    endif
    return lines
endfunction

function! imap#UpdateNew(folder)
    call imap#ListHeaders(a:folder)
    let file_path = mail#GetLocalFolder(a:folder).'/mail'
    let lines = []
ruby << EOF
    file = VIM::evaluate('file_path')
    lines = IO.readlines(file)
    if lines.length > 0
        last_uid = lines[0].gsub(/^\*(\d+).*\*/, '\1').to_i
        imap = Net::IMAP.vim_login
        imap.select(VIM::evaluate('a:folder'))
        imap.uid_fetch(last_uid..-1, ["ENVELOPE", "UID"]).each do |item|
            formatted = format_message_header(item)
            lines.unshift(formatted) if formatted.gsub(/^\*(\d+).*\*/, '\1').to_i > last_uid
        end
        lines.map! {|line| line.gsub(/\r\n|\r|\n/, '')}
        VIM::command("let lines = #{lines}")
        imap.vim_logout
    end
EOF
    if len(lines) > 0
         call writefile(lines, file_path)
    endif
    return lines
endfunction

function! imap#ListFolders(folder)
    let file_path = mail#GetLocalFolder(a:folder).'/folder'
    if filereadable(file_path)
        let lines = readfile(file_path)
    else
        let lines = imap#RefreshFolders(a:folder)
    endif
    return lines
endfunction

function! imap#ShowHeaders(folder)
    call mail#GotoBuffer('MAIL')
    setlocal filetype=mailheaders
    let b:mail_folder = a:folder
    setlocal modifiable
    normal! ggdG
    call append(0, imap#ListHeaders(a:folder))
    normal! gg
    setlocal nomodifiable
    setlocal nomodified
    nnoremap <buffer> <silent> d    :call imap#DeleteMail(b:mail_folder, matchstr(getline('.'), '^\*\zs\d\+'))<cr>
    nnoremap <buffer> <silent> l :call imap#Mail(b:mail_folder, matchstr(getline('.'), '^\*\zs\d\+'))<cr>
    nnoremap <buffer> <silent> <cr> :call imap#Mail(b:mail_folder, matchstr(getline('.'), '^\*\zs\d\+'))<cr>
    execute 'setlocal statusline=%#StatusLineNC#<cr>/l%#StatusLine#:\ Open\ Mail\ %#StatusLineNC#d%#StatusLine#:\ Delete\ Mail\ '.imap#BasicMappings()
endfunction

function! imap#ShowFolders(folder)
    let lines = imap#ListFolders(a:folder)
    call mail#GotoBuffer('MAIL')
    let b:mail_folder = a:folder
    setlocal filetype=mailfolders
    setlocal modifiable
    normal! ggdG
    call append(0, lines)
    normal! gg
    setlocal nomodified
    setlocal nomodifiable
    nnoremap <buffer> <silent> c    :call imap#ShowFolders(b:mail_folder.getline('.'))<cr>
    nnoremap <buffer> <silent> l    :call imap#ShowHeaders(b:mail_folder.getline('.'))<cr>
    nnoremap <buffer> <silent> <cr> :call imap#ShowHeaders(b:mail_folder.getline('.'))<cr>
    execute 'setlocal statusline=%#StatusLineNC#<cr>/l%#StatusLine#:\ Show\ Mails\ %#StatusLineNC#c%#StatusLine#:\ Show\ Folders\ '.imap#BasicMappings()
endfunction

ruby << EOF
def format_message message
    lines = []
    lines << "Date: #{message.date.to_s}"
    lines << "From: <#{message.from.join('>, <')}>"
    lines << "To: <#{message.to.join('>, <')}>"
    if message.cc then lines << "CC: <#{message.cc.join('>, <')}>" end
    lines << "Subject: #{message.subject}"
    lines << ""
    parts = message.multipart? ? message.parts.select { |p| p.content_type =~ /^text\/plain/ } : [message]
    if message.multipart? and parts.empty? then parts = [message] end
    lines.concat parts.map { |p| p.body.decoded.split(/\r\n|\r|\n/) }.flatten
    lines
end
EOF

function! imap#Mail(folder, uid)
    let file_path = mail#GetLocalFolder(a:folder).'/'.a:uid.'.eml'
    call mail#GotoBuffer(string(a:uid))
    let b:mail_folder = a:folder
    let b:mail_file_path = file_path
    if filereadable(file_path)
        let lines = readfile(file_path)
    else
ruby << EOF
        uid = VIM::evaluate('a:uid').to_i
        folder = VIM::evaluate('a:folder')
        imap = Net::IMAP.vim_login
        imap.select(folder)
        lines = []
        imap.fetch(imap.search(["UID", uid]), ["RFC822"]).each do |data|
            lines.concat(data.attr["RFC822"].gsub(/\r\n|\r|\n/, '\n').split('\n')) if data
        end
        imap.vim_logout
        VIM::command("let lines = #{lines}")
EOF
        if len(lines) > 0
            call writefile(lines, file_path)
        endif
    endif
ruby << EOF
    mail = Mail.read(VIM::evaluate('file_path'))
    lines = format_message(mail)
    VIM::command("let lines = #{lines}")
EOF
    setlocal modifiable
    normal! ggdG
    call append(0, lines)
    normal! gg
    setlocal statusline=%#StatusLineNC#r%#StatusLine#:\ Reply
    nnoremap <buffer> <silent> r :call smtp#Reply(b:mail_file_path)<cr>
    setlocal filetype=mail
    setlocal foldmethod=syntax
    setlocal nomodified
    setlocal nomodifiable
endfunction

function! imap#DeleteMail(folder, uid)
ruby << EOF
    imap = Net::IMAP.vim_login
    imap.select(VIM::evaluate('a:folder'))
    uid = VIM::evaluate('a:uid').to_i
    imap.uid_copy(uid, "Trash")
    imap.uid_store(uid, "+FLAGS", [:Deleted])
    imap.vim_logout
EOF
    call imap#RefreshHeaders(a:folder)
    call imap#ShowHeaders(a:folder)
endfunction
