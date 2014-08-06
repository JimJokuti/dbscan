#!/usr/bin/perl --
sub db_connect {
# presupposes the inclusion of: use DBI;

$dberrstr="";

# database information
$connectionInfo="DBI:mysql:database=$db;$host:$port;mysql_connect_timeout=5";
#print "[C: $connectionInfo]\n";

# make connection to database
$dbh = DBI->connect($connectionInfo,$userid,$passwd, {PrintError => 0});
if (!$dbh) {
  $dberrstr="Could not connect: $DBI::errstr";
}


} # end sub

sub db_connectw {
# presupposes the inclusion of: use DBI;

$dberrstr="";

# database information
$connectionInfow="DBI:mysql:database=admin_info;localhost:3306;mysql_connect_timeout=5";
#print "[C: $connectionInfo]\n";

$wuserid="islave_user";
$wpasswd="sl4v3dr1v3r";

# make connection to database
$dbhw = DBI->connect($connectionInfow,$wuserid,$wpasswd, {PrintError => 0});
if (!$dbhw) {
  $dberrstr="Could not connect: $DBI::errstr";
}


} # end sub


sub db_connect0 {
# presupposes the inclusion of: use DBI;

$dberrstr="";

# database information
$connectionInfo0="DBI:mysql:database=$db;$host:$port;mysql_connect_timeout=5";
#print "[C: $connectionInfo]\n";

# make connection to database
$dbh0 = DBI->connect($connectionInfo0,$userid,$passwd, {PrintError => 1});
if (!$dbh0) {
  $dberrstr="Could not connect: $DBI::errstr";
}


} # end sub

sub db_connect1 {
# presupposes the inclusion of: use DBI;

$dberrstr="";

# database information
$connectionInfo1="DBI:mysql:database=admin_info;localhost:3306;mysql_connect_timeout=5";
#print "[C: $connectionInfo]\n";

$userid1="islave_user";
$passwd1="sl4v3dr1v3r";

# make connection to database
$dbh1 = DBI->connect($connectionInfo1,$userid1,$passwd1, {PrintError => 1});
if (!$dbh1) {
  $dberrstr="Could not connect: $DBI::errstr";
} else {
  print " ";
  }

}

sub db_connect2 {
# presupposes the inclusion of: use DBI;

$dberrstr="";

# database information
$connectionInfo2="DBI:mysql:database=admin_info;localhost:3306;mysql_connect_timeout=5";
#print "[C: $connectionInfo]\n";

$userid2="islave_user";
$passwd2="sl4v3dr1v3r";

# make connection to database
$dbh2 = DBI->connect($connectionInfo2,$userid2,$passwd2, {PrintError => 1});
if (!$dbh2) {
  $dberrstr="Could not connect: $DBI::errstr";
} else {
  print " ";
}




} # end sub

sub db_connect3 {
# presupposes the inclusion of: use DBI;

$dberrstr="";

# database information
$connectionInfo3="DBI:mysql:database=admin_info;localhost:3306;mysql_connect_timeout=5";
#print "[C: $connectionInfo]\n";

$userid3="islave_user";
$passwd3="sl4v3dr1v3r";

# make connection to database
$dbh3 = DBI->connect($connectionInfo3,$userid3,$passwd3, {PrintError => 1});
if (!$dbh3) {
  $dberrstr="Could not connect: $DBI::errstr";
} else {
  print " ";
}




} # end sub



sub db_disconnect {

# disconnect from database
$dbh->disconnect;

} #end sub
1;
