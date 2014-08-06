#!/usr/bin/perl --

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


 goto JUSTTHEVARS;

# parse out what to look for in output
( $x, $y, $z ) = split( /\./, $thissubnet );

$checkstring = "$x.$y";

# get the versioning

#$query = "SELECT mysql_version FROM sc_mysql_version ORDER BY mysql_version";
#$sth   = $dbh->prepare($query);
#$sth->execute();
#$sth->bind_columns( undef, \$v );
#while ( $sth->fetch() ) {
#    push( @allversions, $v );
#}

#$raw=`cat mysql_versions.txt`;
#@allversions=split(/\n/,$raw);

$thisoutfilebase = $thissubnet;
$thisoutfilebase =~ s/\//\-/g;

# step 1; scan the subnet, save output

$cmd =
"perl ./pscan.pl -n4 -s -p 3306 -v -l$thissubnet 2> $thisoutfilebase.err > $thisoutfilebase.out";

print "Initial scan in progress...\n\n";

system($cmd);

$output = `cat $thisoutfilebase.out`;

@outputarray = split( /\n/, $output );

foreach $line (@outputarray) {
    $testline = $line;
    $testline =~ s/ //;
    if (   ( "$testline" =~ "$checkstring" )
        && ( "$testline" != ~"scanning" )
        && ( "$testline" =~ "mysql" ) )
    {
        print "\n---\n$line\n";
        ( $thisip, $crap2, $crap, $thisport, $crap ) = split( / /, $line );

        $iaddr = inet_aton($thisip);                # or whatever address
        $name = gethostbyaddr( $iaddr, AF_INET );

        #  print "\n===\n$thisip\n===\n";

        if ( "$name" eq "" ) {
            $name = "NOT_IN_DNS";
        }

        $testvers = $line;
        $testvers =~ s/\(//g;
        $testvers =~ s/\)//g;
        $testvers =~ s/\[//g;
        $testvers =~ s/\]//g;
        $testvers =~ s/\+//g;

        if ( "$testvers" !~ "$name" ) {
            $line =~ s/tcp/\($name\)$thisip tcp/;
            ( $thisip2, $crap2, $crap, $thisport, $crap ) = split( / /, $line );
        }

        ( $crap, $saveit, $crap ) = split( /\(/, $line );
        ( $thishost, $crap ) = split( /\)/, $saveit );
        ( $crap, $saveit, $crap ) = split( /open/, $line );
        ( $thisvers, $crap ) = split( /\-log/, $saveit );

        $thishost = $name;

 #print "[ $thishost ] [$thisip] [ $thisport ]\n$line\n---------------------\n";

        #        $thisvers = substr $thisvers, 1;
        #        $thisvers .= "-log";
        #
        #        # doublecheck
        #        $testvers = $thisvers;
        #        $testvers =~ s/\(//g;
        #        $testvers =~ s/\)//g;
        #
        #        $fflag = 0;

        #        foreach $vers (@allversions) {
        #            if ( "$testvers" =~ "$vers" ) {
        #                $thisvers = $vers;
        #                $fflag    = 1;
        #            }
        #        }
        #        if ( $fflag == 0 ) {
        #
        #            $thisvers =~ s/'/[/;
        #            $thisvers =~ s/'/]/;
        #            $thisvers = substr $thisvers, 1;
        #            if ( "$thisvers" eq "" ) {
        #                $thisvers = "Port is open, but does not respond.";
        #            }
        #        }

        if ( "$crap2" =~ "$thisip" ) {
            print "\n$line\n$thisip|$thishost|$thisvers|$thisport\n";

            $query =
"INSERT INTO sc_instance (ipaddr,ipaddrint,hostname,portnum) VALUES ('$thisip',INET_ATON(ipaddr),'$thishost','$thisport') ON DUPLICATE KEY UPDATE hostname='$thishost',portnum='$thisport',notes='';";

            print "\n$query\n";

            $sth = $dbh->prepare($query);
            $sth->execute();
        }

    }
}

 JUSTTHEVARS:

# now, let's get versioning for reals

( $sn, $mask ) = split( /\//, $thissubnet );

# parse out what to look for in output
( $w, $x, $y, $z ) = split( /\./, $thissubnet );

$thissn = "$w.$x.$y.%";

$query =
"SELECT  id,ipaddr,hostname,portnum FROM sc_instance where ipaddr like '$thissn' and checkflag='Y' ORDER BY hostname";
print $query;

$sth = $dbh->prepare($query);
$sth->execute();
$sth->bind_columns( undef, \$hid, \$hip, \$hn, \$hp );
while ( $sth->fetch() ) {
    push( @allhosts, "$hid:$hip:$hn:$hp" );
}

foreach $host (@allhosts) {
    ( $bid, $bip, $bhost, $bport ) = split( /:/, $host );

    print "$bip|$bhost|$bport\n";

    # database information
    $connectionInfor =
      "DBI:mysql:database=mysql;$bip:$bport;mysql_connect_timeout=5";

    #print "[C: $connectionInfo]\n";

    $ruserid = "rbyrd2";
    $rpasswd = "posaune999";

    # make connection to database
    $dbhr =
      DBI->connect( $connectionInfor, $ruserid, $rpasswd, { PrintError => 0 } );

    #print "here";

    if ( !$dbhr ) {
        $dberrstr = "Could not connect: $DBI::errstr";
        $querybad="UPDATE sc_instance SET notes=\"$dberrstr\" where id=$bid;";
        $sth = $dbh->prepare($querybad);
        $sth->execute();
        goto DEADSERVER;
    } 

    $queryr = "SHOW global variables";

    $sthr = $dbhr->prepare($queryr);

    $ok = DBIx::Timeout->call_with_timeout(
        dbh     => $dbhr,
        code    => sub { $sthr->execute() },
        timeout => 7,
    );

    $queryi = "INSERT INTO sc_variable (iid,keyname,val) VALUES ";
    while ( my ( $key, $val ) = $sthr->fetchrow_array() ) {
print "[$bid|$key|$val]\n";

        $queryi .= "($bid,'$key','$val'),";
        if ( $key eq "version" ) {
            ( $thisvers, $thistype ) = split( /\-/, $val );
            $start = index( $val, '-' );
            $thistype = substr( $val, $start + 1 );

            $queryii =
"INSERT INTO sc_variable (iid,keyname,val) VALUES ($bid,'version_num','$thisvers') ON DUPLICATE KEY UPDATE val='$thisvers';";
            $sth = $dbh->prepare($queryii);
            $sth->execute();
            $queryii =
"INSERT INTO sc_variable (iid,keyname,val) VALUES ($bid,'version_type','$thistype') ON DUPLICATE KEY UPDATE val='$thistype';";
            $sth = $dbh->prepare($queryii);
            $sth->execute();

            $thisversint = $thisvers;
            $thisversint =~ s/[a-z]//g;

            $queryii =
"INSERT INTO sc_variable (iid,keyname,val) VALUES ($bid,'version_int',INET_ATON('$thisversint')) ON DUPLICATE KEY UPDATE val=INET_ATON('$thisversint');";
            $sth = $dbh->prepare($queryii);
            $sth->execute();

            $queryii =
"UPDATE sc_instance set notes='' where id=$bid";
            $sth = $dbh->prepare($queryii);
            $sth->execute();



        }

    }

    chop($queryi);
    $queryi .= " ON DUPLICATE KEY UPDATE val=VALUES(val);";

    $sth = $dbh->prepare($queryi);
    $sth->execute();
DEADSERVER:

}

# after everything is done

$querydone1="UPDATE sc_instance SET subnet= SUBSTRING_INDEX(ipaddr,'.',3);";
$sth = $dbh->prepare($querydone1);
$sth->execute();

$querydone2="UPDATE sc_instance SET subnetint = INET_ATON(subnet);";
$sth = $dbh->prepare($querydone2);
$sth->execute();
