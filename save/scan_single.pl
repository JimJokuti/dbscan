#!/usr/bin/perl --

use DBI;
use Socket qw(AF_INET);
require "lib.pl";

db_connect();


$thissubnet=$ARGV[0];

if ("$thissubnet" eq "") {
  print "USAGE:\n\nscan_single.pl <IPNum>\n\n";
  exit;
}


# parse out what to look for in output
($x,$y,$z)=split(/\./,$thissubnet);

$checkstring="$x.$y";

# get the versioning

$query="SELECT mysql_version FROM sc_mysql_version ORDER BY mysql_version";
$sth = $dbh->prepare($query);
$sth->execute();
$sth->bind_columns(undef, \$v);
while($sth->fetch()) {
  push (@allversions, $v);
}

#$raw=`cat mysql_versions.txt`;
#@allversions=split(/\n/,$raw);

$thisoutfilebase=$thissubnet;
$thisoutfilebase=~s/\//\-/g;

# step 1; scan the subnet, save output

$cmd="perl ./pscan.pl -n4 -s -p 3306 -v -l$thissubnet 2> $thisoutfilebase.err > $thisoutfilebase.out";

print $cmd;

print "Initial scan in progress...\n\n";

system($cmd);



$output=`cat $thisoutfilebase.out`;



@outputarray=split(/\n/,$output);

foreach $line (@outputarray) {
$testline=$line;
$testline=~s/ //;
if (("$line" =~ "$checkstring") && ("$line" !=~ "scanning") && ("$line" =~ "mysql")) {
#  print "$line\n";
  ($thisip,$crap2,$crap,$thisport,$crap)=split(/ /,$line);
  ($crap,$saveit,$crap)=split(/\(/,$line);
  ($thishost,$crap)=split(/\)/,$saveit);
  ($crap,$saveit,$crap)=split(/open/,$line);
  ($thisvers,$crap)=split(/\-log/,$saveit);


print "$thisip...";
  
  $thisvers=substr $thisvers, 2;
  
  # doublecheck
  $testvers=$thisvers;
  $testvers=~s/\(//g;
  $testvers=~s/\)//g;

  $fflag=0;

  foreach $vers (@allversions) {
    if ("$testvers"=~"$vers") {
      $thisvers=$vers;
      $fflag=1;
    } 
  }
  if ( $fflag == 0 ) {

    $thisvers=~s/'/[/;
    $thisvers=~s/'/]/;
    $thisvers=substr $thisvers, 1;
    if ( "$thisvers" eq "" ) {
      $thisvers="Port is open, but does not respond."
    }
  }


if ( "$crap2" =~ "$thisip" ) {
  print "$thisip|$thishost|$thisvers|$thisport\n";
  
  $query="INSERT INTO sc_instance (ipaddr,ipaddrint,hostname,mysql_version,portnum) VALUES ('$thisip',INET_ATON(ipaddr),'$thishost','$thisvers','$thisport') ON DUPLICATE KEY UPDATE hostname='$thishost',mysql_version='$thisvers';";
 
  print "\n$query\n";
 
  $sth = $dbh->prepare($query);
  $sth->execute();
  }
  
}
}

#$cmd="cat $thisoutfilebase" . ".out";
#system($cmd);

