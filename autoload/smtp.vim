ruby require 'mail'

function! smtp#New()
    let filename = '/tmp/vim_mail_'.localtime().'.eml'
    execute 'split '.filename

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

    setlocal filetype=mail

    call setline(1, "From: <".g:mail_address.">")
    call setline(2, "To: <".join(mail_to, ">, <").">")
    call setline(3, "Subject: ".mail_subject)
    call setline(4, "")
    call setline(5, "")
    normal! G
endfunction

function! smtp#Reply(filename)
    let new_file = '/tmp/vim_mail_'.localtime().'.eml'
    execute 'e '.new_file
ruby << EOF
    mail = Mail.read(VIM::evaluate('a:filename'))
    own_address = VIM::evaluate('g:mail_address')
    lines = []
    lines << "From: <#{own_address}>"
    to_list = mail.to
    to_list.delete own_address
    to_str = ""
    to_str << "<#{mail.from.join('>, <')}>"
    if not to_list.empty? then to_str << ", <#{to_list.join('>, <')}>" end
    lines << "To: #{to_str}"
    if mail.cc then lines << "CC: <#{mail.cc.join('>, <')}>" end
    re = (mail.subject =~ /^Re: /) == 0 ? "" : "Re: "
    lines << "Subject: #{re}#{mail.subject}"
    lines << ""
    parts = mail.multipart? ? mail.parts.select { |p| p.content_type =~ /^text\/plain/ } : [mail]
    if mail.multipart? and parts.empty? then parts.concat([mail]) end
    parts.map! do |p|
        list = p.body.decoded.split(/\r\n|\r|\n/)
        list.map! {|l| l.prepend "> "}
    end
    lines.concat parts.flatten
    VIM::command("let lines = #{lines}")
EOF
    call append(0, lines)
    normal! gg}O
endfunction

function! smtp#Send(filename)
ruby << EOF
    file = Mail.read(VIM::evaluate('a:filename'))
    mail = Mail.new do
        from    file.from[0]
        to      file.to[0]
        subject file.subject
        body    file.body.to_s
    end
    server = VIM::evaluate('g:mail_smtp_server')
    port   = VIM::evaluate('g:mail_smtp_port').to_i
    username   = VIM::evaluate('g:mail_address')
    password   = VIM::evaluate('g:mail_password')
    mail.delivery_method :smtp, address: server, port: port, user_name: username, password: password
    mail.deliver
EOF
endfunction
