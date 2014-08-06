#!/usr/bin/expect -f
# catch the date passed on the command line and assign it to a variable
#
# This particular example automates grabbing a backup using a remote server
#

set thedate [lindex $argv 0]

# connect to remote server

spawn scp "user@server:/backups/*$thedate*" /backups_archives

#######################
expect {
-re ".*es.*o.*" {
exp_send "yes\r"
exp_continue
}
-re ".*sword.*" {
exp_send "your_passwordr\r"
}
}
interact
