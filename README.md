# Vim mail

## Configuration
    let g:mail_address="myusername@gmail.com"
    let g:mail_password="PassWord1234"
    let g:mail_smtp_server="smtps://smtp.gmail.com:465"
    let g:mail_imap_server="imaps://imap.gmail.com:993"

## Usage

### SMTP
Use `:SMTPNew` to create a new message. This command will ask for the recipients
to send the message to (the list ends with an empty address)

To send the message use `:SMTPSend` after editing and saving it.

### IMAP
The `:Mail` command puts you in the root folder of your mail. Use `l` to enter
the folder under the cursor and `b` to go back one folder. To list the messages
in the folder under the cursor use `<CR>`. When in the message listing, `<CR>`
opens a new split with the message under the cursor.

#### Mappings
`rf` Refresh the current folder

`rh` Refresh the headers in the current folder

`b`  Go back one folder level
