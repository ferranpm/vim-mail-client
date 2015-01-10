# Vim mail

## Installation
Using [pathogen](https://github.com/tpope/vim-pathogen)
installation is easy:

    % gem install mail netrc
    % cd ~/.vim/bundle
    % git clone http://github.com/ferranpm/vim-mail

## Configuration
Setting server properties

    let g:mail_smtp_server="smtp.gmail.com"
    let g:mail_smtp_port=587
    let g:mail_imap_server="imap.gmail.com"
    let g:mail_imap_port=993
    let g:mail_imap_ssl=1

Setting user/password can be done in your `.vimrc`

    let g:mail_address="myusername@gmail.com"
    let g:mail_password="PassWord1234"

Or in a file specified by `g:mail_netrc`

    let g:mail_netrc="~/.netrc"

Don't forget to put the information in that file!

    machine smtp.gmail.com
        login myusername@gmail.com
        password PassWord1234
    machine imap.gmail.com
        login myusername@gmail.com
        password PassWord1234

## Usage

### SMTP
Use `:WriteMail` to create a new message. This command will prompt for the
recipients to send the message to (the list ends with an empty address).

### IMAP
The `:Mail` command puts you in the root folder of your mail.

### Mappings
On every screen, there's information on the status line about what can be done.
