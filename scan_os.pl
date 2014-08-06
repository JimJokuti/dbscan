#!/usr/bin/perl --

use DBI;
use DBIx::Timeout;
use Socket qw(AF_INET);
require "lib.pl";
use Socket;

# cleanup first
system("rm *.tmp *.cnf");

db_connect();

$thisip = $ARGV[0];

if ( "$thisip" eq "" ) {
    print
"USAGE:\n\nscan_mycnf.pl [IP or subnet wildcard] OR 1\n\n  To scan only a certain range of IPs, use MySQL wildcard syntax, e.g. 10.30.12.%,\n  or else a 1 to scan all subnets.\n\n";
    exit;
}

if ( $thisip != 1 ) {
    $whereclause = " ipaddr LIKE '$thisip' ";
}
else {
    $whereclause = "  checkflag='Y' ";
}

$query =
"SELECT id,ipaddr, hostname,portnum FROM sc_instance where 1=1 and $whereclause  ORDER BY ipaddr,portnum";
$sth = $dbh->prepare($query);
$sth->execute();
$sth->bind_columns( undef, \$hid, \$hip, \$hhn, \$hp );
while ( $sth->fetch() ) {

    # grab the cnfs for running instances on this machine

    $cmd = "bash ./grabmycnf.sh " . $hip;
    system($cmd);

    #$outfiles = `ls -1 $hip_*.cnf`;
    #@outfiles = split( /\n/, $outfiles );
    #
    #foreach $filename (@outfiles) {
    $filename = $hip . "_" . $hp . ".cnf";
    $filestub = $filename;
    $filestub =~ s/.cnf//g;

    ( $thisserver, $thisport ) = split( /_/, $filestub );

    print "\n[$thisserver:$thisport]\n";

    # end id grabbing

    # get data from file

    open CNF, ($filename);
    while (<CNF>) {
        $liner = $_;
        ( $thiskey, $thisval ) = split( /=/, $liner );
        chomp $thisval;
        chomp $thiskey;
        if ( $thisval eq "" ) {
            $thisval = "ON";
        }

        $queryi =
"INSERT INTO sc_mycnf (iid,keyname,val) VALUES ($hid,'$thiskey','$thisval') ON DUPLICATe KEY UPDATE val='$thisval'";

#        print "$queryi\n\n";
        $sth2 = $dbh->prepare($queryi);
        $sth2->execute();
    }
        close CNF;

}

