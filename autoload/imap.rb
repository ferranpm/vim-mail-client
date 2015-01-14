require 'net/imap'
require 'mail'

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

def format_message_header message
    envelope = message.attr["ENVELOPE"]
    uid = '*' + message.attr["UID"].to_s + '*'
    name = envelope.from[0].name || ('<' << (envelope.from[0].mailbox || '') << '@' << (envelope.from[0].host || '') << '>')
    name = Mail::Encodings.value_decode(name) + '                             '
    name = '$$' + name.slice(0..30) + '$$'
    subject = envelope.subject || ''
    subject = '<>' + Mail::Encodings.value_decode(subject) + '<>'
    "#{uid}\t#{name}\t#{subject}"
end

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

def update_headers
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
    else
        Vim::command('call imap#RefreshHeaders(a:folder)')
    end
end

def refresh_headers
    folder = VIM::evaluate('a:folder')
    imap   = Net::IMAP.vim_login
    imap.select(folder)
    lines  = []
    imap.fetch(1..-1, ["ENVELOPE", "UID"]).each do |item|
        lines << format_message_header(item)
    end
    VIM::command("let lines = #{lines.reverse}")
    imap.vim_logout
end

def refresh_folders
    imap = Net::IMAP.vim_login
    folder = VIM::evaluate('a:folder')
    lines = []
    imap.list(folder, "*").each do |f|
        lines << f.name
    end
    imap.vim_logout
    VIM::command("let lines = #{lines}")
end

def get_mail
        uid = VIM::evaluate('a:uid').to_i
        folder = VIM::evaluate('a:folder')
        imap = Net::IMAP.vim_login
        imap.select(folder)
        lines = []
        imap.uid_fetch(uid, ["RFC822"]).each do |data|
            lines.concat(data.attr["RFC822"].gsub(/\r\n|\r|\n/, '\n').split('\n')) if data
        end
        imap.vim_logout
        VIM::command("let lines = #{lines}")
end

def parse_mail
    mail = Mail.read(VIM::evaluate('file_path'))
    lines = format_message(mail)
    VIM::command("let attachments = #{mail.attachments.length}")
    VIM::command("let lines = #{lines}")
end

def archive
    imap = Net::IMAP.vim_login
    imap.select(VIM::evaluate('a:folder_orig'))
    uid = VIM::evaluate('a:uid').to_i
    imap.uid_copy(uid, VIM::evaluate('a:folder_dest'))
    imap.uid_store(uid, "+FLAGS", [:Deleted])
    imap.vim_logout
end

def save_attachments
    mail = Mail.read(VIM::evaluate('expand(a:filename)'))
    dir = VIM::evaluate('expand(path)')
    mail.attachments.each do |attachment|
        filename = attachment.filename
        begin
            File.open(dir + filename, "w+b", 0644) {|f| f.write attachment.body.decoded}
        rescue => e
            puts "Unable to save data for #{filename} because #{e.message}"
        end
    end
end

def delete_mail
    imap = Net::IMAP.vim_login
    imap.select(VIM::evaluate('a:folder'))
    uid = VIM::evaluate('a:uid').to_i
    imap.uid_copy(uid, "Trash")
    imap.uid_store(uid, "+FLAGS", [:Deleted])
    imap.vim_logout
end
