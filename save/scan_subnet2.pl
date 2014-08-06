#!/usr/bin/perl --

use Switch;
use DBI;
use DBIx::Timeout;
use Socket qw(AF_INET);
require "lib.pl";
use Socket;

db_connect();

$thissubnet = $ARGV[0];

if ( "$thissubnet" eq "" ) {
    print
"USAGE:\n\nscan_subnet.pl <subnet_numeric_slash_notation>\n\nExamples 10.10.10.0/24, etc.\n\n";
    exit;
}

# now, let's get versioning for reals

( $sn, $mask ) = split( /\//, $thissubnet );

# parse out what to look for in output
( $w, $x, $y, $z ) = split( /\./, $thissubnet );

$thissn = "$w.$x.$y.%";

$query =
"SELECT  id,hostname,portnum FROM sc_instance where ipaddr like '$thissn' ORDER BY hostname";
#print $query;

$sth = $dbh->prepare($query);
$sth->execute();
$sth->bind_columns( undef, \$hid,\$hn, \$hp );
while ( $sth->fetch() ) {
    push( @allhosts, "$hid:$hn:$hp" );
}

foreach $host (@allhosts) {
    ( $bid,$bhost, $bport ) = split( /:/, $host );

    print "$bhost|$bport\n";

    # database information
    $connectionInfor =
      "DBI:mysql:database=mysql;$bhost:$bport;mysql_connect_timeout=5";

    #print "[C: $connectionInfo]\n";

    $ruserid = "rbyrd2";
    $rpasswd = "posaune999";

    # make connection to database
    $dbhr =
      DBI->connect( $connectionInfor, $ruserid, $rpasswd, { PrintError => 0 } );

#print "here";

    if ( !$dbhr ) {
        $dberrstr = "Could not connect: $DBI::errstr";
    }

        $queryr = "SHOW variables like '%version%'";

        $sthr   = $dbhr->prepare($queryr);

        $ok = DBIx::Timeout->call_with_timeout(
            dbh     => $dbhr,
            code    => sub { $sthr->execute() },
            timeout => 7,
        );

        while ( my ( $key, $val ) = $sthr->fetchrow_array() ) {
            if ( $key eq "protocol_version" ) {
                $thisprocvers = $val;
            }
            elsif ( $key eq "version" ) {
                ($thisvers,$thistype)=split(/\-/,$val);
#                $thisvers = $val;
            }
            elsif ( $key eq "version_comment" ) {
                $thisverscom = $val;
            }
            elsif ( $key eq "version_compile_machine" ) {
                $thisverscm = $val;
            }
            elsif ( $key eq "version_compile_os" ) {
                $thisversco = $val;
            }

        }

        $queryi =
"UPDATE sc_instance SET mysql_version_num='$thisvers',mysql_version_type='$thistype',mysql_version_int=INET_ATON('$thisvers'),mysql_version_comment='$thisverscom',mysql_version_arch='$thisverscm',mysql_version_os='$thisversco' where id=$bid;";

#        print "\n$queryi\n";

        $sth = $dbh->prepare($queryi);
        $sth->execute();

    }

