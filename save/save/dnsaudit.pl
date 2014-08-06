#!/usr/bin/perl --
use Switch;
use DBI;
use DBIx::Timeout;
use Socket qw(AF_INET);
require "lib.pl";

# take care of parameters via the web
$input = $ENV{'QUERY_STRING'};

chomp($input);
if ( $input eq "" ) {
    read( STDIN, $input, $ENV{'CONTENT_LENGTH'} );
}

@pairs = split( /&/, $input );

foreach $pair (@pairs) {
    ( $name, $value ) = split( /=/, $pair );

    $name =~ tr/+/ /;
    $name =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
    $value =~ tr/+/ /;
    $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;

    $saved_params .= "$name=$value&";

    if ( "$name" eq "sn" ) {
        push @snets, $value;

        #      print "\nRLB[ $name : $value ]";
    }
    if ( "$name" eq "sh" ) {
        push @snets, $value;

        #      print "\nRLB[ $name : $value ]";
    }

    $FORM{$name} = $value;

    #    $FORM{$name} = $value;

    #         $fullurl.="$name=$value&";
    #    print "$name: $value<br>";

}

# and just plain argvs

if ("$ARGV[0]") {
    $dowrite = 1;
}

# get rid of that last ampersand
chop($saved_params);

if ( "$csv" == "1" ) {
    gen_csv();
}

$rpttype = $FORM{'t'};
if ( "$rpttype" eq "" ) {
    $rpttype = "f";
}

#print "HTTP/1.0 200 OK\n";

$whereami="DNS Reconciliation";
if ($rpttype eq "d") {
  $whereami="Instances missing from DNS";
}
header();

print "
<style type=\"text/css\">
table.var-table {
width: 75%;
table-layout:fixed;
text-align:left;
vertical-align:top;
padding: 5px;
}

table.var-table tr {
vertical-align:top;
text-align:left;
}

table.var-table td.kw,
table.var-table th.kw {
width: 50%;
}

table.var-table td.var,
table.var-table th.var {
width: 50%;
word-wrap: break-word;
}

</style>
";


gen_report();

exit;

sub gen_report() {

    db_connect();

    if ( "$rpttype" eq "f" ) {
        $where    = "WHERE i.hostname='NOT_IN_DNS' OR v.val != i.hostname ";
        $subtitle = "All inequalities: DNS, Instance, IP";
    }
    elsif ( "$rpttype" eq "d" ) {
        $where    = "WHERE i.hostname='NOT_IN_DNS' ";
        $subtitle = "Instances missing from DNS";
    }

    $query =
"SELECT i.id,i.ipaddr,i.hostname AS dns_hostname,v.val AS sr_hostname FROM sc_instance i LEFT JOIN sc_variable v ON i.id=v.iid AND v.keyname='hostname' $where  ORDER BY i.hostname,v.val;";

    #    print "$query";
    $sth = $dbh->prepare($query);
    $sth->execute() or die($DBI::errstr);
    $sth->bind_columns( undef, \$id, \$ipaddr, \$dnshostname, \$srhostname );

    $counter = 0;
    $out .=
"<tr bgcolor=grey><td colspan=4><font size=+1><font color=linen><b>MySQL Instance DNS Reconciliation Report</font><br><font size=+0 color=silver>$subtitle</td></tr>\n";

    $out .=
"<tr bgcolor=silver><td><b>DNS Hostname</b></td><td><b>Instance-reported hostname</b></td><td><b>IP address</b></td></tr>\n";
    $linecounter = 0;

    while ( $sth->fetch() ) {

        $linecounter++;
        if ( $linecounter == 2 ) {
            $linecounter = 0;
            $bgcolor     = $nicolor;
        }
        else {
            $bgcolor = "white";
        }

        $out .=
"<tr bgcolor=$bgcolor><td>$dnshostname</td><td>$srhostname</td><td>$ipaddr</td></tr>\n";

    }

    $out .= "</table>";

    $out = "<table align=center width=650>$out</table>";
    print $out;

}
