#!/usr/bin/perl --

use DBI;
use DBIx::Timeout;
use Socket qw(AF_INET);
require "lib.pl";
use Socket;

db_connect();

$query =
"SELECT  fqdn from dbhost  ORDER BY fqdn";

$sth = $dbh->prepare($query);
$sth->execute();
$sth->bind_columns( undef, \$fqdn );
while ( $sth->fetch() ) {

 $packed_ip = gethostbyname($fqdn);
 if (defined $packed_ip) {
 $ip_address = inet_ntoa($packed_ip);
 }

print "$ip_address\n";

($a, $b, $c, $d) = split(/\./,$ip_address);
$subnet=$a . "." . $b . "." . $c;


            $query2 =
"UPDATE dbhost set vip='$ip_address',subnet='$subnet' where fqdn='$fqdn';";
            $sth2 = $dbh->prepare($query2);
            $sth2->execute();


}
