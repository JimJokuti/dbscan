#!/usr/bin/perl --
#!/usr/bin/perl --
use Switch;
use DBI;
use DBIx::Timeout;
require "lib.pl";
use Socket qw(AF_INET);

db_connect();

$query = "SHOW variables like '%version%'";
$sth   = $dbh->prepare($query);

$ok = DBIx::Timeout->call_with_timeout(
    dbh     => $dbh,
    code    => sub { $sth->execute() },
    timeout => 7,
);

#            $result = $sth->fetchrow_arrayref();

#print "got result\n";


while (my ($key,$val) = $sth->fetchrow_array()) {
        if ( $key eq "protocol_version" ) {
            $thisprocvers = $val;
        }
        elsif ( $key eq "version" ) {
            $thisvers = $val;
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

        print "|$key|$val|\n";
    }
    print "---\n";

print "$thisversion";
