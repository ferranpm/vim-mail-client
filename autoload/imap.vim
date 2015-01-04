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
    nnoremap <buffer> <silent> rh :call imap#RefreshHeaders(b:mail_folder)<cr>:call imap#ShowHeaders(b:mail_folder)<cr>
    nnoremap <buffer> <silent> rf :call imap#RefreshFolders(b:mail_folder)<cr>:call imap#ShowFolders(b:mail_folder)<cr>
    nnoremap <buffer> <silent> b :call imap#ShowFolders(imap#BackFolder(b:mail_folder))<cr>
endfunction

function! imap#CreateIfNecessary(folder)
    let local_path = mail#GetLocalFolder(a:folder)
    if !isdirectory(local_path)
        call mkdir(local_path, "p")
    endif
endfunction

function! imap#RefreshHeaders(folder)
    call imap#CreateIfNecessary(a:folder)
    let file_path = mail#GetLocalFolder(a:folder).'/mail'
    let lines = []
ruby << EOF
    folder = VIM::evaluate('a:folder')
    imap   = Net::IMAP.vim_login
    imap.select(folder)
    lines  = []
    imap.fetch(1..-1, ["ENVELOPE", "UID"]).each do |item|
        envelope = item.attr["ENVELOPE"]
        uid = item.attr["UID"]
        name = envelope.from[0].name || ''
        name = '$' + Mail::Encodings.value_decode(name) + '$                             '
        name.slice!(30..name.length)
        subject = envelope.subject || ''
        subject = Mail::Encodings.value_decode(subject)
        lines << "*#{uid}*\t$#{name}$\t<>#{subject}<>"
    end
    VIM::command("let lines = #{lines.reverse}")
    imap.vim_logout
EOF
    call writefile(lines, file_path)
    return lines
endfunction

function! imap#RefreshFolders(folder)
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
    call writefile(lines, file_path)
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
    normal ggdG
    call append(0, imap#ListHeaders(a:folder))
    normal gg
    setlocal nomodifiable
    setlocal nomodified
    call imap#BasicMappings()
    nnoremap <buffer> <silent> <cr> :call imap#Mail(b:mail_folder, matchstr(getline('.'), '^\*\zs\d\+'))<cr>
endfunction

function! imap#ShowFolders(folder)
    let lines = imap#ListFolders(a:folder)
    call mail#GotoBuffer('MAIL')
    let b:mail_folder = a:folder
    setlocal filetype=mailfolders
    setlocal modifiable
    normal ggdG
    call append(0, lines)
    normal gg
    setlocal nomodified
    setlocal nomodifiable
    call imap#BasicMappings()
    nnoremap <buffer> <silent> l :call imap#ShowFolders(b:mail_folder.getline('.'))<cr>
    nnoremap <buffer> <silent> <cr> :call imap#ShowHeaders(b:mail_folder.getline('.'))<cr>
endfunction

function! imap#BackFolder(folder)
    let list = split(a:folder, '/')
    call remove(list, len(list) - 1)
    return join(list, '/')
endfunction

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
        data = imap.fetch(imap.search(["UID", uid]), ["RFC822"])
        imap.vim_logout
        if data
            lines = data[0].attr["RFC822"].gsub(/\r\n|\r|\n/, '\n').split('\n')
            VIM::command("let lines = #{lines}")
        end
EOF
        call writefile(lines, file_path)
    endif
ruby << EOF
    mail = Mail.read(VIM::evaluate('file_path'))
    lines = []
    lines << "Date: #{mail.date.to_s}"
    lines << "From: <#{mail.from.join('>, <')}>"
    lines << "To: <#{mail.to.join('>, <')}>"
    if mail.cc then lines << "CC: <#{mail.cc.join('>, <')}>" end
    lines << "Subject: #{mail.subject}"
    lines << ""
    parts = mail.multipart? ? mail.parts.select { |p| p.content_type =~ /^text\/plain/ } : [mail]
    if mail.multipart? and parts.empty? then parts.concat([mail]) end
    lines.concat parts.map { |p| p.body.decoded.split(/\r\n|\r|\n/) }.flatten
    VIM::command("let lines = #{lines}")
EOF
    setlocal modifiable
    normal ggdG
    call append(0, lines)
    normal gg
    nnoremap <buffer> <silent> r :call smtp#Reply(b:mail_file_path)<cr>
    setlocal filetype=mail
    setlocal foldmethod=syntax foldlevel=0
    setlocal nomodified
    setlocal nomodifiable
endfunction
