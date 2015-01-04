ruby require 'mail'

function! smtp#New()
    let filename = '/tmp/vim_mail_'.localtime().'.eml'
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
