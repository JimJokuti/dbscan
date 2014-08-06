use Socket;
$iaddr = inet_aton("10.20.16.45"); # or whatever address
$name  = gethostbyaddr($iaddr, AF_INET);

print $name;

