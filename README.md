# Vim mail

## Installation
Using [pathogen](https://github.com/tpope/vim-pathogen)
installation is easy:

    % gem install mail
    % cd ~/.vim/bundle
    % git clone http://github.com/ferranpm/vim-mail

## Configuration
    let g:mail_address="myusername@gmail.com"
    let g:mail_password="PassWord1234"
    let g:mail_smtp_server="smtp.gmail.com"
    let g:mail_smtp_port=587
    let g:mail_imap_server="imap.gmail.com"
    let g:mail_imap_port=993
    let g:mail_imap_ssl=1

## Usage

### SMTP
Use `:SMTPNew` to create a new message. This command will ask for the recipients
to send the message to (the list ends with an empty address)

To send the message use `:SMTPSend` after editing and saving it.

### IMAP
The `:Mail` command puts you in the root folder of your mail. Use `l` to enter
the folder under the cursor and `b` to go back one folder. When in the message
listing, `<CR>` opens a new split with the message under the cursor.

#### Mappings
On a mail/folder listing window `rh` refreshes the list in the current folder
and `rf` refreshes the current folder (and subfolders)

When viewing a message press `r` to reply it.
