#!/usr/bin/perl --
use Switch;
use DBI;
#use DBIx::Timeout;
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

# version filter
$vf = $FORM{'vf'};
if ( "$vf" ne "" ) {
    $versclause = " AND v.val=\"$vf\" ";
    $vershr     = "Showing MySQL version = $vf";
}
else {
    $vershr = "Showing all MySQL versions";
}

# order, for later
$order = $FORM{'o'};
$csv   = $FORM{'csv'};

if ( "$order" eq "i" ) {
    $orderclause = "ORDER BY i.ipaddrint, i.portnum";
    $orderhr     = "Sorted by IP and port number";
}
elsif ( "$order" eq "h" ) {
    $orderclause = "ORDER BY i.hostname, i.portnum";
    $orderhr     = "Sorted by hostname and port number";
}
elsif ( "$order" eq "v" ) {
    $orderclause = "ORDER BY INET_ATON(v.val), i.ipaddrint, i.portnum";
    $orderhr     = "Sorted by MySQL version, IP, and port number";
}
elsif ( "$order" eq "s" ) {
    $orderclause = "ORDER BY s.subnetint, i.ipaddrint, i.portnum";
    $orderhr     = "Sorted by subnet, IP, and port number";
}
elsif ( "$order" eq "v" ) {
    $orderclause = "ORDER BY i.updated, i.ipaddrint, i.portnum";
    $orderhr     = "Sorted by modified date, IP, and port number";
}
else {
    $orderclause = "ORDER BY i.ipaddrint, i.portnum";
    $orderhr     = "Sorted by IP and port number";
}


if ( "$csv" == "1" ) {
    gen_csv();
}

#print "HTTP/1.0 200 OK\n";
gen_filter();

#use Capture::Tiny ':all';


$whereami="View subnets and servers";
header();

$string=$FORM{'str'};
if ("$string" ne "") {
  search_for_string();
  exit;
}


if ( ( $FORM{'sn'} ne "" ) || ( $FORM{'sh'} ne "" ) ) {
    gen_report();
    exit;
}

# Get subnets

$out =
'<input type="checkbox" onClick="toggle1(this)" /><b>Toggle all subnets</b><br/>';

db_connect();

$query =
"SELECT id,subnet, description FROM sc_subnet WHERE addrclass='C' ORDER BY description;";
$sth = $dbh->prepare($query);
$sth->execute();
$sth->bind_columns( undef, \$id, \$subnettoscan, \$subnetdesc );

$outcnt = -1;
while ( $sth->fetch() ) {
    $outcnt++;
    if ( $outcnt == 10 ) {
        $out .= "</td>\n<td valign=top>";
        $outcnt = 0;
    }
    $out .=
"<input type=checkbox value=$id name=sn>&nbsp;$subnetdesc ($subnettoscan)</input><br>";
}

$out = "<table width=100%><tr><td valign=top>" . $out;
$out .= "</tr></table>";
print "<form action=index.pl method=get>$out";

print
"<table align=right><tr><td>$filterdd<input type=submit value='Show these subnets'></td></tr></table><br>&nbsp;<br></form>";

#print "<table align=right><tr><td><input type=submit value='Show these subnets'></td></tr></table><br>&nbsp;<br></form>";
print $divider;

# Get shards
#$out =
#'<input type="checkbox" onClick="toggle2(this)" /><b>Toggle all shards</b><br/>';
#
#db_connect();
#
#$query =
#"SELECT id,subnet, description FROM sc_subnet WHERE addrclass='B' ORDER BY description;";
#$sth = $dbh->prepare($query);
#$sth->execute();
#$sth->bind_columns( undef, \$id, \$subnettoscan, \$subnetdesc );
#
#$outcnt = -1;
#while ( $sth->fetch() ) {
#    $outcnt++;
#    if ( $outcnt == 10 ) {
#        $out .= "</td>\n<td valign=top>";
#        $outcnt = 0;
#    }
#    $out .=
#"<input type=checkbox value=$id name=sh>&nbsp;$subnetdesc ($subnettoscan)</input><br>";
#}
#
#$out = "<table width=100%><tr><td valign=top>" . $out;
#$out .= "</tr></table>";
#print "<form action=index.pl method=get>$out";
#
#print
#"<table align=right><tr><td>$filterdd<input type=submit value='Show these shards'></td></tr></table><br>&nbsp;<br></form>";
#print $divider;
print
"<a href=\"mailto:rbyrd2\@searshc.com?subject=MySQL Audit suggestion\">Email Richard a suggestion for improvement</a>";

sub gen_report() {

    foreach $sn (@snets) {
        $snclause .= "$sn,";
        $snparams .= "sn=$sn&";

        #  print "[$sn]";
    }

    chop($snclause);
    chop($snparams);

    $snparams .= "&vf=$vf";

    $snclause = " WHERE s.id IN ($snclause) ";

    #print $snclause;
    db_connect();
    db_connect2();

    $query =
"SELECT s.id,s.subnet, s.description FROM sc_subnet s $snclause ORDER BY s.subnetint";

    #print "$query";
    $sth = $dbh->prepare($query);
    $sth->execute() or die($DBI::errstr);
    $sth->bind_columns( undef, \$subnetid, \$subnetnum, \$subnetdesc );

    $counter = 0;

    while ( $sth->fetch() ) {
        ( $one, $two, $three ) = split( /\./, $subnetnum );
        if ( "$three" eq "" ) {
            $subnetnumdis = $subnetnum . ".0";
        }
        else {
            $subnetnumdis = $subnetnum;
        }

        #print $counter;
        $out .=
"<tr bgcolor=grey><td colspan=6><font size=+1><font color=linen><b>$subnetdesc</b> ($subnetnumdis.0/24)</font></td></tr>";
        $out .=
"<tr bgcolor=silver><td><b><a href=index.pl?$snparams&o=i title='Click to sort'>IP Address</a></b></td><td><b><a href=index.pl?$snparams&o=h title='Click to sort'>DNS hostname (Instance reported hostname)</a></b></td></td><td><b><a title='Click to sort' href=index.pl?$snparams&o=v>MySQL version</a></b></td><td><b><a title='Click to sort' href=index.pl?$snparams&o=s>Subnet</a></b></td><td><b>SN Desc</b></td><td><b><a title='Click to sort' href=index.pl?$snparams&o=m>Modified</a></b></td></tr>\n";


        if ( "$three" ne "" ) {
            $thisclause = " AND s.id=$subnetid ";
        }
        else {
            $ipstr      = $subnetnum . ".%";
            $thisclause = " AND i.ipaddr LIKE '$ipstr' ";
        }

        $query2 =
"SELECT i.id,i.ipaddr, i.hostname, i.portnum, i.modified, s.subnet, s.description, v.val AS mysql_version,v2.val as srhostname, v3.val as verscom,i.notes
           FROM sc_instance i LEFT JOIN sc_subnet s ON s.subnet = SUBSTRING_INDEX(i.ipaddr, '.', 3)
           LEFT JOIN sc_variable v ON v.iid=i.id  AND v.keyname = 'version_num' left join sc_variable v2 on v2.iid=i.id AND v2.keyname='hostname' left join sc_variable v3 on v3.iid=i.id and v3.keyname='version_comment' WHERE s.addrclass = 'C'  "
          . $thisclause
          . "$versclause $orderclause ;";

        #print "[ $query2 ]";

        $sth2 = $dbh2->prepare($query2);
        $sth2->execute() or die($DBI::errstr);
        $sth2->bind_columns(
            undef,        \$id,\$ipaddr, \$hostname,    \$portnum,
            \$modified,   \$subnet, \$description, \$mysqlversion,
            \$srhostname, \$verscom,\$notes
        );

        $outcnt   = -1;
        $hcounter = 0;
        $linecounter=0;
        
        while ( $sth2->fetch() ) {
            $counter++;
            $hcounter++;

            if (( "$hostname" ne "$srhostname" ) && ("$srhostname" ne "")){
                $displayhostname = "$hostname ($srhostname)";
            }
            else {
                $displayhostname = $hostname;
            }



            $linecounter++;
            if ( $linecounter == 2 ) {
                $linecounter = 0;
                $bgcolor     = $nicolor;
            }
            else {
                $bgcolor = "white";
            }

            if ("$notes" =~ /Could not connect/) {
                $verscom="Access to this instance denied";
            }


            $out .=
"<tr bgcolor=$bgcolor><td><a class=srv href=serverdetails.pl?s=$id title='Click for server details'>$ipaddr:$portnum</a></td><td><a class=srv href=serverdetails.pl?s=$id title='Click for server details'>$displayhostname</a></td></td><td>$mysqlversion $verscom</td><td>$subnet</td><td>$description</td><td>$modified</td></tr>\n";

        }

        $out .=
"<tr bgcolor=white><td colspan=6>$divider Total hosts known: $hcounter</td></tr>";

    }

    $out = "<table width=100%>$out</table>";
    print $out;

}

sub gen_csv() {

    foreach $sn (@snets) {
        $snclause .= "$sn,";
        $snparams .= "sn=$sn&";

        #  print "[$sn]";
    }
    chop($snclause);
    chop($snparams);

    $snclause = " WHERE s.id IN ($snclause) ";

    #print $snclause;
    db_connect();
    db_connect2();

    $query =
"SELECT s.id,s.subnet, s.description FROM sc_subnet s $snclause ORDER BY s.subnetint";

    #print "$query";
    $sth = $dbh->prepare($query);
    $sth->execute() or die($DBI::errstr);
    $sth->bind_columns( undef, \$subnetid, \$subnetnum, \$subnetdesc );

    $counter = 0;

    while ( $sth->fetch() ) {

        ( $one, $two, $three ) = split( /\./, $subnetnum );
        if ( "$three" eq "" ) {
            $subnetnumdis = $subnetnum . ".0";
        }
        else {
            $subnetnumdis = $subnetnum;
        }

        #$out.="THREE: [$three] xxxxx";

        #print $counter;
        $out .= "$subnetdesc,($subnetnumdis.0/24)\n";
        $out .=
"\"IP Address\",\"Port\",\"Hostname\",\"MySQL version\",\"Subnet\",\"SN Desc\",\"Modified\"\n";

        if ( "$three" ne "" ) {
            $thisclause = " AND s.id=$subnetid ";
        }
        else {
            $ipstr      = $subnetnum . ".%";
            $thisclause = " AND i.ipaddr LIKE '$ipstr' ";
        }

# $thisclause=" AND s.id=$subnetid ";
#  $query2="SELECT i.ipaddr, i.hostname, i.portnum, i.modified, s.subnet, s.description, i.mysql_version
#              FROM
#              sc_instance i
#              LEFT JOIN sc_subnet s
#              ON s.subnet = SUBSTRING_INDEX(i.ipaddr, '.', 3)
#              WHERE s.addrclass = 'C' " . $thisclause . "$versclause $orderclause";

        #$out.="[ $query2 ]";
        $sth2 = $dbh2->prepare($query2);
        $sth2->execute() or die($DBI::errstr);
        $sth2->bind_columns( undef, \$ipaddr, \$hostname, \$portnum,
            \$modified, \$subnet, \$description, \$mysqlversion );

        $outcnt   = -1;
        $hcounter = 0;
        while ( $sth2->fetch() ) {
            $counter++;
            $hcounter++;

            $out .=
"\"$ipaddr\",\"$portnum\",\"$hostname\",\"$mysqlversion\",\"$subnet\",\"$description\",\"$modified\"\n";

        }

    }

    open( OUT, '>tmp/mysql_locations.csv' );
    print OUT "$out\n";
    close(OUT);

    print "Location: tmp/mysql_locations.csv\n\n";
}

sub gen_filter() {

    if ( "$ft" eq "m" ) {
        $filtertypehr = "MySQL version";
        $filterclause = " AND mysql_version='$ff' ";
    }

    db_connect();

    $query =
"SELECT   val,    COUNT(val)     FROM      sc_variable         WHERE keyname='version_num'        GROUP BY val        ORDER BY val";
    $sth = $dbh->prepare($query);
    $sth->execute() or die($DBI::errstr);
    $sth->bind_columns( undef, \$versnum, \$numinst );

    $counter = 0;

    while ( $sth->fetch() ) {

        if ( "$versnum" eq "$vf" ) {
            $selected = "selected";
        }
        else {
            $selected = "";
        }

        $filterdd .=
"<option $selected value=\"$versnum\">$versnum ($numinst instances)</option>\n";
    }

    $filterdd =
"\nVersion filter: <select name=vf><option value=\"\">All versions</option>\n"
      . $filterdd
      . "</select>";

}    # end sub


sub search_for_string {

    db_connect();
    db_connect2();

$whereclause="  
  AND CONCAT_WS(
    ',',
    LOWER(s.subnet),
    LOWER(s.description),
    LOWER(i.ipaddr),
    LOWER(i.hostname),
    LOWER(i.portnum),
    LOWER(v.val),LOWER(v2.val),LOWER(v3.val),LOWER(i.notes)) LIKE '%$string%'
 ";



    $query =
"SELECT s.id,s.subnet, s.description,i.id,i.ipaddr,i.hostname,i.portnum,v.val as mysqlversion,v2.val as srhostname,v3.val as verscom,i.modified,i.notes FROM sc_subnet s left join sc_instance i on i.subnetint=s.subnetint
left join sc_variable v on v.iid=i.id and v.keyname='version' left join sc_variable v2 on v2.iid=i.id and v2.keyname='hostname' left join sc_variable v3 on v3.iid=i.id and v3.keyname='version_comment' WHERE 1=1 $whereclause $orderclause";

#    print "$query";
    
$out.=    "<tr bgcolor=silver><td><b><a href=index.pl?str=$string&o=i title='Click to sort'>IP Address</a></b></td><td><b><a href=index.pl?str=$string&o=h title='Click to sort'>DNS hostname (Instance reported hostname)</a></b></td></td><td><b><a title='Click to sort' href=index.pl?str=$string&o=v>MySQL version</a></b></td><td><b><a title='Click to sort' href=index.pl?str=$string&o=s>Subnet</a></b></td><td><b>SN Desc</b></td><td><b><a title='Click to sort' href=index.pl?str=$string&o=m>Modified</a></b></td></tr>\n";

    
    $sth2 = $dbh->prepare($query);
    $sth2->execute() or die($DBI::errstr);
    $sth2->bind_columns( undef, \$subnetid, \$subnetnum, \$subnetdesc,\$id,\$ipaddr, \$hostname,    \$portnum,\$mysqlversion,
               \$srhostname, \$verscom ,\$modified,\$notes);

    $counter = 0;


        $outcnt   = -1;
        $hcounter = 0;
        $linecounter=0;
        
        while ( $sth2->fetch() ) {
            $counter++;
            $hcounter++;

            if (( "$hostname" ne "$srhostname" ) && ("$srhostname" ne "")){
                $displayhostname = "$hostname ($srhostname)";
            }
            else {
                $displayhostname = $hostname;
            }



            $linecounter++;
            if ( $linecounter == 2 ) {
                $linecounter = 0;
                $bgcolor     = $nicolor;
            }
            else {
                $bgcolor = "white";
            }


            if ("$notes" =~ /Could not connect/) {
                $verscom="Access to this instance denied";
            }




            $out .=
"<tr bgcolor=$bgcolor><td><a class=srv href=serverdetails.pl?s=$id title='Click for server details'>$ipaddr:$portnum</a></td><td><a class=srv href=serverdetails.pl?s=$id title='Click for server details'>$displayhostname</a></td></td><td>$mysqlversion $verscom</td><td>$subnetnum</td><td>$subnetdesc</td><td>$modified</td></tr>\n";

        }

        $out .=
"<tr bgcolor=white><td colspan=6>$divider Total hosts known: $hcounter</td></tr>";


    $out = "<table width=100%>$out</table>";
    print $out;






} # end sub search_for_string