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

build_instance_dd();

if ("$FORM{'s2'}" eq "" ) {
  $whereami="Server details";
} else {
  $whereami="Configuration diffs";
}

header();
print "<HEAD>


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


$header2 .=
"<center><form action=serverdetails.pl><font size=-1>Choose another instance or diff two servers' config: $dd1&nbsp;$dd2 <input type=submit value=Go></input></form></center>";

# "</td><td align=right><a href=index.pl>Return to index</a><br><!-- <a href=index.pl?$saved_params&csv=1 target=new>Export as CSV</a> --></td></tr></table>";

$header2 .= "<table cellspacing=0 cellpadding=0>";
$divider = "<hr size=1 noshade color=silver>\n";

print $header2;
print $divider;

if ( $FORM{'s2'} ne "" ) {
    gen_diff();
    exit;
}

if ( $FORM{'s'} ne "" ) {
    gen_report();
    exit;
}

sub gen_report() {

    $server = $FORM{'s'};

    $serverclause = " WHERE i.id = $server ";
    $varclause    = " WHERE iid=$server ";

    db_connect();
    db_connect2();

    $query =
"SELECT i.id,i.ipaddr,i.hostname,i.portnum,i.subnet,i.notes,i.modified,s.description FROM sc_instance i LEFT JOIN sc_subnet s ON s.subnetint=i.subnetint $serverclause";

    #print "$query";
    $sth = $dbh->prepare($query);
    $sth->execute() or die($DBI::errstr);
    $sth->bind_columns(
        undef,     \$sid,    \$ipaddr, \$hostname,
        \$portnum, \$subnet, \$notes,  \$smodified,
        \$subnetdesc
    );

    $counter = 0;

    while ( $sth->fetch() ) {

        #print $counter;
        $out .=
"<tr bgcolor=grey><td colspan=4><font size=+1><font color=linen><b>$hostname ($ipaddr)</b> in $subnetdesc</b> ($subnet) modified on $smodified</font></td></tr>";

        $query2 =
          "SELECT keyname,val FROM sc_variable $varclause ORDER BY keyname;";

        #print "[ $query2 ]";

        $sth2 = $dbh2->prepare($query2);
        $sth2->execute() or die($DBI::errstr);
        $sth2->bind_columns( undef, \$keyname, \$val );
        $numrows     = $sth2->rows;
        $breakpoint  = int( $numrows / 2 );
        $linecounter = 0;
        $counter     = 0;
        $thiscol     = 1;
        while ( $sth2->fetch() ) {

            if ( $counter == $breakpoint ) {
                $thiscol     = 2;
                $linecounter = 0;
            }
            $counter++;

            $linecounter++;
            if ( $linecounter == 2 ) {
                $linecounter = 0;
                $bgcolor     = $nicolor;
            }
            else {
                $bgcolor = "white";
            }

            $column[$thiscol] .=
"<tr><td bgcolor=$bgcolor>$keyname</td><td bgcolor=$bgcolor class=var>$val</td></tr>\n";

        }

        $column[1] =
"<table class=var-table align=right><tr bgcolor=silver><td><b>Variable</b></td><td><b>Value</b></td></tr>\n"
          . $column[1]
          . "</table>";
        $column[2] =
"<table class=var-table><tr bgcolor=silver><td><b>Variable</b></td><td class=var><b>Value</b></td></tr>\n"
          . $column[2]
          . "</table>";

        $out .=
          "<tr><td colspan=4>$numrows variables for this server.&nbsp;&nbsp;<a href=gencnf.pl?s=$sid target=mycnf>Generate a my.cnf</a> based on these variables</a></td></tr>\n";
        $out .=
"<tr><td width=50% valign=top style=\"text-wrap:normal;word-wrap:break-word;\">$column[1]</td><td width=50% valign=top style=\"text-wrap:normal;word-wrap:break-word;\">$column[2]</td></tr>";

        $out .= "</table>";

    }

    $out = "<table width=100%>$out</table>";
    print $out;

}

sub build_instance_dd {
    $server  = $FORM{'s'};
    $server2 = $FORM{'s2'};

    db_connect2();
    $instquery =
      "SELECT id,ipaddr,hostname,portnum FROM sc_instance ORDER BY hostname;";
    $sth3 = $dbh2->prepare($instquery);
    $sth3->execute() or die($DBI::errstr);
    $sth3->bind_columns( undef, \$iid, \$iip, \$ihostname, \$iportnum );
    while ( $sth3->fetch() ) {

        # get server reported hostname
        $miscquery =
          "SELECT val from sc_variable where iid=$iid and keyname='hostname';";
        $sth4 = $dbh2->prepare($miscquery);
        $sth4->execute() or die($DBI::errstr);
        $sth4->bind_columns( undef, \$srhostname );
        while ( $sth4->fetch() ) {
        }

        $selected  = "";
        $selected2 = "";

        if ( $server eq $iid ) {
            $selected = "selected";
        }
        if ( $server2 eq $iid ) {
            $selected2 = "selected";
        }
        $dd1 .=
"<option value=$iid $selected>$ihostname:$iportnum ($srhostname/$iip)</option>\n";
        $dd2 .=
"<option value=$iid $selected2>$ihostname:$iportnum ($srhostname/$iip)</option>\n";
    }

    $dd1 =
"<select name=s>\n<option value=''>Choose an instance</option>\n$dd1\n</select>";
    $dd2 =
"<select name=s2>\n<option value=''>Choose instance to diff (optional)</option>\n$dd2\n</select>";

}    #end build_instance_dd

sub gen_diff {

    $server  = $FORM{'s'};
    $server2 = $FORM{'s2'};

    db_connect();
    db_connect2();

    $query =
"SELECT i.id,i.ipaddr,i.hostname,i.portnum,i.subnet,i.notes,i.modified,s.description,v.val FROM sc_instance i LEFT JOIN sc_subnet s ON s.subnetint=i.subnetint left join sc_variable v on v.iid=i.id and v.keyname='hostname' WHERE i.id=$server";

    #print "$query";
    $sth = $dbh->prepare($query);
    $sth->execute() or die($DBI::errstr);
    $sth->bind_columns(
        undef,        \$sid,    \$ipaddr, \$hostname,
        \$portnum,    \$subnet, \$notes,  \$smodified,
        \$subnetdesc, \$srhostname
    );

    $counter = 0;

    while ( $sth->fetch() ) {
    }

    $query =
"SELECT i.id,i.ipaddr,i.hostname,i.portnum,i.subnet,i.notes,i.modified,s.description,v.val FROM sc_instance i LEFT JOIN sc_subnet s ON s.subnetint=i.subnetint left join sc_variable v on v.iid=i.id and v.keyname='hostname'WHERE i.id=$server2";

    #print "$query";
    $sth = $dbh->prepare($query);
    $sth->execute() or die($DBI::errstr);
    $sth->bind_columns(
        undef,         \$sid2,    \$ipaddr2, \$hostname2,
        \$portnum2,    \$subnet2, \$notes2,  \$smodified2,
        \$subnetdesc2, \$srhostname2
    );

    $counter = 0;

    while ( $sth->fetch() ) {
    }

#print $counter;
#        $out .=
#"<tr bgcolor=grey><td colspan=2><font size=+1><font color=linen><b>Instance A: $hostname ($ipaddr)</b> in $subnetdesc</b> ($subnet) modified on $smodified</font></td>
#<td colspan=2><font size=+1><font color=linen><b>Instance B: $hostname2 ($ipaddr2)</b> in $subnetdesc2</b> ($subnet2) modified on $smodified2</font></td>
#</tr>";

    $query2 = "SELECT 
            v1.keyname,
            v1.val,
            v2.keyname,
            v2.val 
            FROM
            sc_variable v1 
            LEFT JOIN sc_variable v2 
            ON v1.keyname = v2.keyname 
            AND v1.val != v2.val 
            WHERE v1.iid = $sid
            AND v2.iid = $sid2 
            ORDER BY v1.keyname ;";

    #print "[ $query2 ]";
    $linecounter = 0;

    $sth2 = $dbh2->prepare($query2);
    $sth2->execute() or die($DBI::errstr);
    $sth2->bind_columns( undef, \$keyname1, \$val1, \$keyname2, \$val2 );

    while ( $sth2->fetch() ) {
        $numrows = $sth2->rows;
        $counter = 0;
        $thiscol = 1;

        $linecounter++;
        if ( $linecounter == 2 ) {
            $linecounter = 0;
            $bgcolor     = $nicolor;
        }
        else {
            $bgcolor = "white";
        }

        $diffout .=
"<tr><td bgcolor=$bgcolor>$keyname1</td><td bgcolor=$bgcolor class=var>$val1</td><td bgcolor=$bgcolor class=var>$val2</td></tr>\n";

    }

    $diffout =
"<table class=var-table align=center><tr bgcolor=silver><td><b>Variable</b></td><td><b>$hostname:$portnum<br>($srhostname/$ipaddr)</b></td><td><b>$hostname2:$portnum2<br>($srhostname2/$ipaddr2)</b></td></tr>\n"
      . $diffout
      . "</table>";

    $out .=
"<tr><td colspan=4>$numrows differences between these instances</td></tr>\n";
    $out .=
"<tr><td width=50% valign=top style=\"text-wrap:normal;word-wrap:break-word;\">$diffout</td></tr>";

    $out .= "</table>";

    $out = "<table width=100%>$out</table>";
    print $out;

}
