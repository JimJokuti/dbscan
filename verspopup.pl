#!/usr/bin/perl --
print "Content-type: text/html\n\n";



use Switch;
use DBI;
#use DBIx::Timeout;
use Socket qw(AF_INET);

require "lib.pl";




    db_connect();

    $query =
"SELECT swversion,date(reldate),notes from sc_appinfo order by reldate desc";

    $sth = $dbh->prepare($query);
    $sth->execute() or die($DBI::errstr);
    $sth->bind_columns(
        undef,     \$swversion,    \$reldate, \$notes
    );

$counter=0;

print "
<style type=text/css>
body{
margin: 0;
padding: 0
}
</style>
<body marginheight=0 marginleft=0 marginright=0><table cellspacing=1 cellpadding=3 noshade width=100%><tr bgcolor=gray><td colspan=3><font face=arial font size=+1 color=white><b>Version History</font></td></tr>
<tr bgcolor=silver><td><font face=arial size=-1><b>Version</b>&nbsp;&nbsp;</td><td><font face=arial size=-1><b>Release&nbsp;date</b>&nbsp;&nbsp;</td><td><font face=arial size=-1><b>Notes</b></td></tr>";

    while ( $sth->fetch() ) {
    
    $counter++;
    if ($counter>1) {
      $counter=0;
      $bgcolor="#E0F2F7";
      } else {
      $bgcolor="white";
      }
      
    print "<tr bgcolor=$bgcolor><td align=left valign=top><font face=arial size=-1>$swversion</td><td align=left valign=top><font face=arial size=-1>$reldate</td><td align=justify valign=top><font face=arial size=-1>$notes</td></tr>";

}


print "</table>";

