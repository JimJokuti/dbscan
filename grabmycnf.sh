#!/bin/sh

# CONSTANTS

#username=dba
#password=N0\#20uch\!T

username=rbyrd
password=l1s4t4l0r


server=$1

echo -n Examining server ${server}:

./autologin.sh ${username} ${password} ${server} 22  cat /etc/*release /proc/version | tail -2 > version.data

echo Done with $server.

  

