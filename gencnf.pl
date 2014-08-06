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


$sid=$FORM{'s'};
if ("$sid" eq "") {
  print "No direct access.";
  exit;
}

#print "HTTP/1.0 200 OK\n";
print "Content-type: text/html\n\n";

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



<style type=\"text/css\">  /*this is what we want the div to look like    when it is not showing*/  div.loading-invisible{    /*make invisible*/    display:none;  }  /*this is what we want the div to look like    when it IS showing*/  div.loading-visible{    /*make visible*/    display:block;    /*position it 200px down the screen*/    position:absolute;    top:5px;    left:0;    width:100%;    text-align:center;    /*in supporting browsers, make it      a little transparent*/    background:#fff;    filter: alpha(opacity=75); /* internet explorer */    -khtml-opacity: 0.75;      /* khtml, old safari */    -moz-opacity: 0.75;       /* mozilla, netscape */    opacity: 0.75;           /* fx, safari, opera */    border-top:1px solid #fff;    border-bottom:1px solid #fff;  }</style>

</HEAD>

<BODY>
<div id=\"loading\" class=\"loading-invisible\">  <p><img src=loading_trans.gif><br><i>(~20 seconds)</i></p></div>
<script type=\"text/javascript\">  document.getElementById(\"loading\").className = \"loading-visible\";  var hideDiv = function(){document.getElementById(\"loading\").className = \"loading-invisible\";};  var oldLoad = window.onload;  var newLoad = oldLoad ? function(){hideDiv.call(this);oldLoad.call(this);} : hideDiv;  window.onload = newLoad;</script>


<TITLE>MySQL Location Audit: Generate my.cnf</TITLE>\n
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

$whereami="DNS Reconciliation";
if ($rpttype eq "d") {
  $whereami="Instances missing from DNS";
}

gen_cnf();

exit;

sub gen_cnf() {

    db_connect();


    $query =
"SELECT i.ipaddr,i.hostname,i.portnum,v.keyname,v.val from sc_instance i left join sc_variable v on v.iid=i.id where i.id=$sid ORDER BY v.keyname;";

    #    print "$query";
    $sth = $dbh->prepare($query);
    $sth->execute() or die($DBI::errstr);
    $sth->bind_columns( undef, \$ipaddr,\$hostname,\$portnum,\$keyname,\$val );


    while ( $sth->fetch() ) {

      if (("$keyname" ne "hostname") && ($keyname !~ /version/)){
        $keylen=length($keyname);
        $spaces=50-$keylen;
        $thisline=$keyname . " " x $spaces . "= $val\n";
        $out .="$thisline";
      }

    }

    chomp($now);
    $out = "<font size=+0><pre># my.cnf generated by http://dbadmin/dbtools/dbscan/gencnf.pl on $now.\n# Based on $hostname:$portnum ($ipaddr)\n# Eventually I'll format this in a more standard way.  For now, alphabetical.\n\n" . $out . "</pre>";

    print $out;

}
