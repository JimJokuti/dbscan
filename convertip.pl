#!/usr/bin/perl 
$ip_address = $ARGV[0]; 
@octets = split(/\./, $ip_address); 
$DEC = ($octets[0]*1<<24)+($octets[1]*1<<16)+($octets[2]*1<<8)+($octets[3]); 
print "The IP Address $ip_address converts to decimal $DEC\n" 
