#!/usr/bin/perl --

use DBI;
use Socket qw(AF_INET);
require "lib.pl";

db_connect();

$query="SELECT id,subnet, description FROM sc_subnet WHERE addrclass='C' ORDER BY subnetint;";
$sth = $dbh->prepare($query);
$sth->execute();
$sth->bind_columns(undef, \$id,\$subnettoscan,\$subnetdesc);
while($sth->fetch()) {

  $param="$subnettoscan" . ".0/24";
  $cmd="perl ./scan_subnet.pl $param";

  print "\n\n-----------------------------------------------------------------------\nScanning $param (id: $id) - $subnetdesc...\n-----------------------------------------------------------------------\n";  

  system($cmd);


}


