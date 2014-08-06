$filename="10.20.16.33_3306.cnf";
    open CNF, ($filename);
    while (<CNF>) {
        $liner = $_;
        ( $thiskey, $thisval ) = split( /=/, $liner );
        chomp $thisval;
        chomp $thiskey;
        
        print "KEY: $thiskey -- VAL: $thisval\n";
        
        
        }
