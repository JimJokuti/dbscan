db_connect();

$query =
"SELECT id,subnet, description FROM sc_subnet WHERE addrclass='C' ORDER BY subnetint;";
$sth = $dbh->prepare($query);
$sth->execute();
$sth->bind_columns( undef, \$id, \$subnettoscan, \$subnetdesc );

$outcnt = -1;
while ( $sth->fetch() ) {
    $outcnt++;
    if ( $outcnt == 18 ) {
        $out .= "</td>\n<td valign=top>";
        $outcnt = 0;
    }
    $out .=
"<input type=checkbox value=$id name=sn>&nbsp;$subnetdesc ($subnettoscan)</input><br>";
}
