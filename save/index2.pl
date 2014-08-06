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

$saved_params.="$name=$value&";

    if ("$name" eq "sn") {
      push @snets, $value;
#      print "\nRLB[ $name : $value ]";
    }
    if ("$name" eq "sh") {
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

# order, for later
$order=$FORM{'o'};
$csv=$FORM{'csv'};

if ("$order" eq "i") {
  $orderclause="ORDER BY i.ipaddrint, i.portnum";
  $orderhr="Sorted by IP and port number";
} elsif ("$order" eq "h" ) {
  $orderclause="ORDER BY i.hostname, i.portnum";
  $orderhr="Sorted by hostname and port number";
} elsif ("$order" eq "v" ) {
  $orderclause="ORDER BY i.mysql_version_int, i.ipaddrint, i.portnum";
  $orderhr="Sorted by MySQL version, IP, and port number";
} elsif ("$order" eq "s" ) {
  $orderclause="ORDER BY s.subnetint, i.ipaddrint, i.portnum";
  $orderhr="Sorted by subnet, IP, and port number";
} elsif ("$order" eq "v" ) {
  $orderclause="ORDER BY i.updated, i.ipaddrint, i.portnum";
  $orderhr="Sorted by modified date, IP, and port number";
} else { 
  $orderclause="ORDER BY i.ipaddrint, i.portnum";
  $orderhr="Sorted by IP and port number";
}
  
if ("$order" eq "") {
  $orderhr="";
}

if ("$csv" == "1") {
  gen_csv();
}

#print "HTTP/1.0 200 OK\n";
print "Content-type: text/html\n\n";

print "<HEAD>

<script language=\"JavaScript\">
function toggle1(source) {
  checkboxes = document.getElementsByName('sn');
  for(var i=0, n=checkboxes.length;i<n;i++) {
  checkboxes[i].checked = source.checked;
  }
}

function toggle2(source) {
  checkboxes = document.getElementsByName('sh');
  for(var i=0, n=checkboxes.length;i<n;i++) {
  checkboxes[i].checked = source.checked;
  }
}



</script>

<style type=\"text/css\">  /*this is what we want the div to look like    when it is not showing*/  div.loading-invisible{    /*make invisible*/    display:none;  }  /*this is what we want the div to look like    when it IS showing*/  div.loading-visible{    /*make visible*/    display:block;    /*position it 200px down the screen*/    position:absolute;    top:5px;    left:0;    width:100%;    text-align:center;    /*in supporting browsers, make it      a little transparent*/    background:#fff;    filter: alpha(opacity=75); /* internet explorer */    -khtml-opacity: 0.75;      /* khtml, old safari */    -moz-opacity: 0.75;       /* mozilla, netscape */    opacity: 0.75;           /* fx, safari, opera */    border-top:1px solid #fff;    border-bottom:1px solid #fff;  }</style>

</HEAD>

<BODY>
<div id=\"loading\" class=\"loading-invisible\">  <p><img src=loading_trans.gif><br><i>(~20 seconds)</i></p></div>
<script type=\"text/javascript\">  document.getElementById(\"loading\").className = \"loading-visible\";  var hideDiv = function(){document.getElementById(\"loading\").className = \"loading-invisible\";};  var oldLoad = window.onload;  var newLoad = oldLoad ? function(){hideDiv.call(this);oldLoad.call(this);} : hideDiv;  window.onload = newLoad;</script>


<TITLE>MySQL Instance Locations: $now</TITLE>\n
<style type=\"text/css\">
body { font-family: \"Trebuchet MS\", Arial, Helvetica, sans-serif; font-size: 10;}
table, th, td
 {
  font-size: 13;
   }
   
a:link {color:darkgreen;}      /* unvisited link */
 a:visited {color:darkgreen;}  /* visited link */
  a:hover {color:linen;}  /* mouse over link */
   a:active {color:linen;}  /* selected link */    
   
   
</style> 
";

gen_filter();

#use Capture::Tiny ':all';

$header ="
<table width=100%>
<tr>
<td>
<font face=arial size=4><b>MySQL Global Location Audit</b></font><br>\n";

$now         = `date`;

$header .= "<i>$now</i><br>";
$header .= "$orderhr<br>";
$header .= "</td><td align=right><a href=index.pl>Return to top</a><br><a href=index.pl?$saved_params&csv=1 target=new>Export as CSV</a></td></tr></table>";

$header .=
"<table cellspacing=0 cellpadding=0>";
# <tr><td>LEGEND:&nbsp;&nbsp;</td><td $nibg>No issues</td><td bgcolor=white>&nbsp;&nbsp;</td><td $offlinecolor>Instance offline</td><td bgcolor=white>&nbsp;&nbsp;</td><td $behindcolor>Significantly behind</td><td bgcolor=white>&nbsp;&nbsp;</td><td $catchcolor>Catching up</td><td bgcolor=white>&nbsp;&nbsp;</td><td $deadcolor>Unreachable</td><td bgcolor=white>&nbsp;&nbsp;</td><td $nodaemon>No daemon</td></tr></table>";
$divider = "<hr size=1 noshade color=silver>\n";

print $header;
print $divider;


if (($FORM{'sn'} ne "") || ($FORM{'sh'} ne "")){
  gen_report();
  exit;
}


# Get subnets


$out='<input type="checkbox" onClick="toggle1(this)" /><b>Toggle all subnets</b><br/>';

db_connect();

$query="SELECT id,subnet, description FROM sc_subnet WHERE addrclass='C' ORDER BY description;";
$sth = $dbh->prepare($query);
$sth->execute();
$sth->bind_columns(undef, \$id,\$subnettoscan,\$subnetdesc);

$outcnt=-1;
while($sth->fetch()) {
  $outcnt++;
  if ($outcnt == 10) {
    $out.="</td>\n<td valign=top>";
    $outcnt=0;
  }
  $out.= "<input type=checkbox value=$id name=sn>&nbsp;$subnetdesc ($subnettoscan)</input><br>";
}

$out="<table width=100%><tr><td valign=top>" . $out;
$out.="</tr></table>";
print "<form action=index.pl method=get>$out";

print "<table align=right><tr><td>$filterdd<input type=submit value='Show these subnets'></td></tr></table><br>&nbsp;<br></form>";
#print "<table align=right><tr><td><input type=submit value='Show these subnets'></td></tr></table><br>&nbsp;<br></form>";
print $divider;


# Get shards
$out='<input type="checkbox" onClick="toggle2(this)" /><b>Toggle all shards</b><br/>';

db_connect();

$query="SELECT id,subnet, description FROM sc_subnet WHERE addrclass='B' ORDER BY description;";
$sth = $dbh->prepare($query);
$sth->execute();
$sth->bind_columns(undef, \$id,\$subnettoscan,\$subnetdesc);

$outcnt=-1;
while($sth->fetch()) {
  $outcnt++;
  if ($outcnt == 10) {
    $out.="</td>\n<td valign=top>";
    $outcnt=0;
  }
  $out.= "<input type=checkbox value=$id name=sh>&nbsp;$subnetdesc ($subnettoscan)</input><br>";
}

$out="<table width=100%><tr><td valign=top>" . $out;
$out.="</tr></table>";
print "<form action=index.pl method=get>$out";

print "<table align=right><tr><td><input type=submit value='Show these shards'></td></tr></table><br>&nbsp;<br></form>";
print $divider;
print "<a href=\"mailto:rbyrd\@riotgames.com?subject=MySQL Audit suggestion\">Email Richard a suggestion for improvement</a>";







sub gen_report() {


foreach $sn (@snets) {
  $snclause.= "$sn,";
  $snparams.="sn=$sn&";
#  print "[$sn]";
}
chop($snclause);
chop($snparams);

$snclause= " WHERE s.id IN ($snclause) ";


#print $snclause;
db_connect();
db_connect2();

$query="SELECT s.id,s.subnet, s.description FROM sc_subnet s $snclause ORDER BY s.subnetint";
#print "$query";              
$sth = $dbh->prepare($query);
$sth->execute() or die($DBI::errstr);
$sth->bind_columns(undef, \$subnetid,\$subnetnum,\$subnetdesc);

$counter=0;

while($sth->fetch()) {
($one,$two,$three)=split(/\./,$subnetnum);
if ("$three" eq "") {
  $subnetnumdis=$subnetnum . ".0";
} else {
  $subnetnumdis=$subnetnum;
}



#print $counter;
  $out.="<tr bgcolor=grey><td colspan=6><font size=+1><font color=linen><b>$subnetdesc</b> ($subnetnumdis.0/24)</font></td></tr>"; 
  $out.="<tr bgcolor=silver><td><b><a href=index.pl?$snparams&o=i>IP Address</a></b></td><td><b><a href=index.pl?$snparams&o=h>Hostname</a></b></td></td><td><b><a href=index.pl?$snparams&o=v>MySQL version</a></b></td><td><b><a href=index.pl?$snparams&o=s>Subnet</a></b></td><td><b>SN Desc</b></td><td><b><a href=index.pl?$snparams&o=m>Modified</a></b></td></tr>\n";


if ("$three" ne "") {
 $thisclause=" AND s.id=$subnetid ";
} else {
 $ipstr=$subnetnum . ".%";
 $thisclause=" AND i.ipaddr LIKE '$ipstr' ";
}

  $query2="SELECT i.ipaddr, i.hostname, i.portnum, i.modified, s.subnet, s.description, i.mysql_version 
              FROM
              sc_instance i 
              LEFT JOIN sc_subnet s 
              ON s.subnet = SUBSTRING_INDEX(i.ipaddr, '.', 3) 
              WHERE s.addrclass = 'C' " . $thisclause . " $orderclause ;";
              
#print "[ $query2 ]";              
  $sth2 = $dbh2->prepare($query2);
  $sth2->execute()  or die($DBI::errstr);;
  $sth2->bind_columns(undef, \$ipaddr,\$hostname,\$portnum,\$modified,\$subnet,\$description,\$mysqlversion);

  $outcnt=-1;
  $hcounter=0;
  while($sth2->fetch()) {
$counter++;
$hcounter++;

    $out.="<tr><td>$ipaddr:$portnum</td><td>$hostname</td></td><td>$mysqlversion</td><td>$subnet</td><td>$description</td><td>$modified</td></tr>\n";


  }

  $out.="<tr bgcolor=white><td colspan=6>$divider Total hosts this shard: $hcounter</td></tr>"; 


}

$out="<table width=100%>$out</table>";
print $out;


}

sub gen_csv() {


foreach $sn (@snets) {
  $snclause.= "$sn,";
  $snparams.="sn=$sn&";
#  print "[$sn]";
}
chop($snclause);
chop($snparams);

$snclause= " WHERE s.id IN ($snclause) ";


#print $snclause;
db_connect();
db_connect2();

$query="SELECT s.id,s.subnet, s.description FROM sc_subnet s $snclause ORDER BY s.subnetint";
#print "$query";              
$sth = $dbh->prepare($query);
$sth->execute() or die($DBI::errstr);
$sth->bind_columns(undef, \$subnetid,\$subnetnum,\$subnetdesc);

$counter=0;

while($sth->fetch()) {

($one,$two,$three)=split(/\./,$subnetnum);
if ("$three" eq "") {
  $subnetnumdis=$subnetnum . ".0";
} else {
  $subnetnumdis=$subnetnum;
}

#$out.="THREE: [$three] xxxxx";

#print $counter;
  $out.="$subnetdesc,($subnetnumdis.0/24)\n"; 
  $out.="\"IP Address\",\"Port\",\"Hostname\",\"MySQL version\",\"Subnet\",\"SN Desc\",\"Modified\"\n";

if ("$three" ne "") {
 $thisclause=" AND s.id=$subnetid ";
} else {
 $ipstr=$subnetnum . ".%";
 $thisclause=" AND i.ipaddr LIKE '$ipstr' ";
}


# $thisclause=" AND s.id=$subnetid ";
  $query2="SELECT i.ipaddr, i.hostname, i.portnum, i.modified, s.subnet, s.description, i.mysql_version 
              FROM
              sc_instance i 
              LEFT JOIN sc_subnet s 
              ON s.subnet = SUBSTRING_INDEX(i.ipaddr, '.', 3) 
              WHERE s.addrclass = 'C' " . $thisclause . " $orderclause ;";
              
              
              
#$out.="[ $query2 ]";              
  $sth2 = $dbh2->prepare($query2);
  $sth2->execute()  or die($DBI::errstr);;
  $sth2->bind_columns(undef, \$ipaddr,\$hostname,\$portnum,\$modified,\$subnet,\$description,\$mysqlversion);

  $outcnt=-1;
  $hcounter=0;
  while($sth2->fetch()) {
$counter++;
$hcounter++;

    $out.="\"$ipaddr\",\"$portnum\",\"$hostname\",\"$mysqlversion\",\"$subnet\",\"$description\",\"$modified\"\n";


  }


}

open (OUT,'>tmp/mysql_locations.csv');
print OUT "$out\n";
close (OUT);

print "Location: tmp/mysql_locations.csv\n\n";
}



sub gen_filter() {

if ( "$ft" eq "m" ) {
  $filtertypehr="MySQL version";
  $filterclause=" AND mysql_version='$ff' ";
}



db_connect();

$query="SELECT DISTINCT COUNT(mysql_version),mysql_version FROM sc_instance WHERE mysql_version NOT LIKE ' ./p%' GROUP BY mysql_version ORDER BY mysql_version_int;";
$sth = $dbh->prepare($query);
$sth->execute() or die($DBI::errstr);
$sth->bind_columns(undef, \$numinst,\$versnum);

$counter=0;

while($sth->fetch()) {

if ("$versnum" eq "$vf") {
  $selected="selected";
  } else {
  $selected="";
  }
  
$filterdd.="<option $selected value=\"$versnum\">$versnum ($numinst instances)</option>\n";
}



$filterdd="\nVersion filter: <select name=vf><option value=\"\">All versions</option>\n" . $filterdd . "</select>";


} # end sub