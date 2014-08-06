#!/usr/bin/perl
#---------------------------------------
# Basic port scanner with banner grabbing.
#   Writen by MadHat (madhat@unspecific.com)
# http://www.unspecific.com/mp/port-scanner/
#
# Both command line and web based interface.
#
# Copyright (c) 2001-2002, MadHat (madhat@unspecific.com)
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in
#     the documentation and/or other materials provided with the distribution.
#   * Neither the name of MadHat Productions nor the names of its
#     contributors may be used to endorse or promote products derived
#     from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
# TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#---------------------------------------

$VERSION = '2.3.9';
#
#
#
#

use CGI qw/:standard/;
# use CGI::Carp qw/fatalsToBrowser/;

use Getopt::Std;
use POSIX qw(:sys_wait_h);
use Socket qw(:DEFAULT :crlf);
use Time::HiRes qw(alarm);
use LWP::UserAgent;
use Crypt::SSLeay;
use Net::Ping;
use locale;

$SIG{CHLD}='IGNORE';
$SIG{USR2}=\&open_port;
$| = 0;
$ENV{PATH} = '/bin:/usr/bin:/usr/local/bin';
# $nbtscan = `which nbtscan`; chomp $nbtscan;
if (-e 'services') {
  $services_file = 'services';
} else {
  $services_file = '/etc/services';
}

$start = time;

  %affected_ssh = ssh_info();
  %banners = banner_info();

sub doScan{
  print "Debug Level: " . $opt_d . "\n" if ($opt_d);
  print "Running as a CGI\n" if ($CGI and $opt_d);
  my @nets;
  if ( defined($opt_i) ){
    open(FIN, "$opt_i" ) || die "cannot open $opt_i\n";
    @nets=<FIN>;
    close(FIN);
  } elsif ( defined($opt_l) ) {
    if ($opt_l eq '-') {
      $opt_l = join(',', <STDIN>);
    }
    @nets = split(',', $opt_l);
  }
  foreach $net (@nets){
    chomp $net;
    next if ($net =~ /^#/ or $net =~ /^$/);
    print "scanning $net\n" if (defined($opt_v));
    @iplist = calculate_ip_range($net);
    push(@totallist, @iplist);
  }
  scanNet(@totallist);
}

sub scanNet{
  my @iplist = @_;
  if (!@iplist) { die "Error in the IP list. Check syntax.
    IP list entered: $ip
    Allowed Syntax:
    a.b.c.d/n       - 10.0.0.1/25
    a.b.c.*         - 10.0.0.* (0-255) same as /24
    a.b.c.d/w.x.y.z - 10.0.0.0/255.255.224.0 (standard format)
    a.b.c.d/w.x.y.z - 10.0.0.0/0.0.16.255    (cisco format)
    a.b.c.d-z       - 10.1.2.0-12
    a.b.c-x.*       - 10.0.0-3.*  (last octet has to be * or 0)
    a.b.c-x.d       - 10.0.0-3.0
    hostname        - www.unspecific.com
  \n"; }
  my $ipnum = $#iplist;
  my $prnt=1;  #
  my @CHILDREN;
  my %port_list;
  if ($> == 0) {
    $ping_type = 'icmp';
  } else {
  print "Warning: Using TCP ping, not as reliable\n"
    . "Run as root, or use -P to override\n\n" 
    if ( ($opt_v or $opt_d) and $opt_P);
    $ping_type = 'tcp';
  }
  print "Generating port list from file\n" if ($opt_d > 1);
  open (SERV, $services_file) or print"Can't scan standard ports: $!\n";
  while (<SERV>) {
    chomp;
    /^([\w-_]+)\s+(\d{1,5})\/\w{3}/;
    if ($2 and !$port_list{$2}) {
      $port_list{$2} = $1;
      print "Adding $2($1) to the port list from\n- $_\n" if ($opt_d > 3);
    }
  }
  close (SERV);
  if ($opt_p !~ /^\d{1,5}$/) {
    print "Calculating port list from $opt_p\n" if ($opt_d > 1);
    @ports = split(',', $opt_p);
    # look to see if there are any entries that need to be expanded
    for $port (@ports) {
      if ($port =~ /^(\d{1,5}\.\.\d{1,5})$/) {
        for (eval($1)) {
          print "adding port $_ to port list\n" if ($opt_d > 1);
          push @port_list, $_;
        }
      } elsif ($port =~ /^(\d{1,5})\-(\d{1,5})$/) {
        for ($1..$2) {
          print "adding port $_ to port list\n" if ($opt_d > 1);
          push @port_list, $_;
        }
      } elsif ($port =~ /^(\d{1,5})$/) {
        push @port_list, $port;
      } elsif ($port =~ /^\w+$/) {
         print "This is a named port $port\n" if ($opt_d);
         PORT: for my $cport (keys %port_list) {
           if ($port eq $port_list{$cport}) {
             push @port_list, $cport;
             print "$port found to be $cport\n" if ($opt_d);
             last PORT;
           }
         }
      }
      $location++;
    }
    if ($#port_list < 0 and !$opt_s and $iplist[0] !~ /:\d{1,6}/) {
      &usage;
      exit;
    }
  } else {
    push @port_list, $opt_p;
  }
  for ( $i = 0; $i<=$#iplist; $i++ ){
    my $ipaddr = $iplist[$i];
    chomp $ipaddr;

    ###########################################
    # Start Flow Control
    WAIT: while ( $#CHILDREN >= $opt_n ){
      print STDERR "$cli_exec ($$): Parent waiting. $i of $#iplist ($#CHILDREN Running)\n"
        if ($opt_d > 1);
      my $CHILD_pos = 0;
      for $pid (@CHILDREN) {
        $waitpid = waitpid($pid, WNOHANG);
        if ($waitpid != 0) {
          print STDERR "$cli_exec ($$): child $pid exited, cleaning up ($?)\n"
            if ($opt_d > 1);
          splice(@CHILDREN, $CHILD_pos, 1);
          kill 9, $pid;
          next WAIT;
        } 
        $CHILD_pos++;
      }
      sleep 1;
    }
    # End Flow Control
    ###########################################

    my $thisthread = fork;
    if (!defined($thisthread) ) {
      print "FORK Died $ipaddr <=========\n";
    } else {
      if ( $thisthread == 0 ) {
        $0 = $ipaddr;
        my @port_list;
        if ($ipaddr =~ s/^(.+):(\d{1,5})/$1/) { push @port_list, $2 }
        # child
        #
        if ($opt_P) {
          $p = Net::Ping->new($ping_type);
          if (!$p->ping($ipaddr,$opt_t)) {
            print "Host($ipaddr) does not appear to be up, SKIPPING\n\n" 
              if ($opt_d);
            $p->close;
            exit 0;
          }
          $p->close;
        }
        $dnsaddr = inet_aton($ipaddr);
        $dnsname = gethostbyaddr($dnsaddr, AF_INET);
        $dnsname = $dnsname?$dnsname:'NOT_IN_DNS';
        $total_out_for_host = "$ipaddr ($dnsname)";
        $0 = "Scanning $ipaddr($dnsname)";
        if ($opt_N and -e $nbtscan) {
          print "Grabbing NetBIOS name\n" if ($opt_d > 1);
          @data = split (' ', `$nbtscan -q $ipaddr`);
          $netbios = $data[1];
          $total_out_for_host .= " - $netbios";
        } elsif ($opt_N) {
          print "Unable to grab NetBIOS name from $nbtscan\n" if ($opt_d > 1);
        }
#        $total_out_for_host .= "\n";
        if ($opt_s) {
          # Scan here.
          print "Start scanning\n" if ($opt_d > 1);
          print STDERR "$cli_exec ($$): got $dnsname from DNS server for $ipaddr\n"
            if ($opt_d);
          for $port (sort {$a <=> $b} keys %port_list) {
            $counter++;
            print "Scanning $ipaddr:$port\n" if ($opt_d > 1);
            $output = scan_port($ipaddr, $port, $port_list{$port});
            if ($output) {
              $output_flag = 1;
              $total_out_for_host .= "$output\n";
            }
          }
          # $total_scanned = $#port_list + 1;
          # $total_out_for_host .= "Total ports scanned: $total_scanned\n\n";
          print "$total_out_for_host\n" if ($output_flag);
          exit 0;
        } else {
          # Scan here.
          print "Start scanning\n" if ($opt_d > 1);
          for $port (sort {$a <=> $b} @port_list) {
            print "Scanning $ipaddr:$port\n" if ($opt_d > 1);
            my $output = scan_port($ipaddr, $port, $port_list{$port});
            if ($output) {
              $output_flagged = 1;
              $total_out_for_host .= "$output\n";
            }
          }
          if ($output_flagged) {
            # $total_scanned = $#port_list + 1;
            # $total_out_for_host .= "Total ports scanned: $total_scanned\n\n";
            print "$total_out_for_host\n";
          }
          exit 0;
        } 
      } else {
        # parent
        $parent=$$;
        print "This is the Parent for pid $thisthread for ip $ipaddr\n" if ($opt_d > 1);
        push ( @CHILDREN, $thisthread);
      }
    }
  }
}

$SIG{ALRM} = sub {
  print "Socket Timeout\n" if ($opt_d > 1);
  close(TO_SCAN);
};

sub scan_port {
  my ($ipaddr, $port, $port_name) = @_;
  $port_name = $port_name?$port_name:'Unknown';
  $0 = "Scanning $ipaddr:$port($port_name)";
  print "Scanning $ipaddr:$port($port_name)\n" if ($opt_d);
  my $output = "$ipaddr ";
  my $open = '';
  my $buffer = '';
  my @rawdata = ();
  if (!$opt_v) {
    if (check_port($ipaddr, $port, 'TCP', $opt_t)) {
      print "Adding $port\n" if ($opt_d);
      $output .= "tcp $port ($port_name) open";
      return $output;
    }
  }
  eval {
    $0 = "Scanning $ipaddr:$port($port_name)";
    local $SIG{__WARN__};
    local $SIG{'__DIE__'} = "DEFAULT";
    local $SIG{'ALRM'} = sub { die (join '', @rawdata) };
    my $p_addr = sockaddr_in($port, inet_aton($ipaddr) );
    print "Socket initialized:\n" if ($opt_d > 2);
    socket(TO_SCAN,PF_INET,SOCK_STREAM,getprotobyname('TCP'))
    or die "Error: Unable to open socket: $@";
    alarm($opt_t);
    if (connect(TO_SCAN, $p_addr)) {
      print "Adding $port\n" if ($opt_d);
      $output .= "tcp $port ($port_name) open";
      kill USR2, $parent if ($opt_v);
      $open = 1;
      alarm($opt_t);
      READSOCK: while (!eof(TO_SCAN)) {
        read(TO_SCAN,$rawdata,1);
        push @rawdata, $rawdata;
        if ( join('', @rawdata) eq ' !"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefg') {
          @rawdata = (split ('', 'Character Generator'));
          close(TO_SCAN);
        }
      }
      print STDERR "$cli_exec ($$): Closing RAW Socket\n"
        if ($opt_d > 1);
      close (TO_SCAN);
      alarm(0);
      $buffer = join('', @rawdata);
    }
  };
  if (!$open) { return }
  if ($@ and $@ !~ /^Died at / and !$buffer) {
    $buffer = $@;
    $buffer =~ s/at \S+ line 321.$//;
  }
  if ($buffer) {
    $buffer =~ s/\n|\r//g;
    print "Buffer set to $buffer from socket\n" if ($opt_d);
    print "Normallizing Buffer\n" if ($opt_d);
    if ($buffer =~ /(SSH\-\S+) /) {
      $ssh_version = $1;
      print "SSH Found $ssh_version $affected_ssh{$ssh_version}\n" if ($opt_d );
      $buffer = "$ssh_version $affected_ssh{$ssh_version}";
    }
    if ($buffer =~ /^RFB (\d{3})\.(\d{3})/) {
      my $major_version = $1;
      my $minor_version = $2;
      $major_version =~ s/^0+//;
      $minor_version =~ s/^0+//;
      print "VNC/RFB Found $buffer \n" if ($opt_d );
      $buffer = "VNC-RFB/$major_version.$minor_version\n";
    }
    BANNER: for $grep (sort keys %banners) {
      print "Checking buffer for $grep\n" if ($opt_d );
      if ($buffer =~ /$grep/ ){
        my $version = $1;
        $buffer = "$banners{$grep}/$version";
        print "Setting buffer to $buffer\n" if ($opt_d );
        last BANNER;
      }
    }
  }
  if (!$buffer) {
    $buffer = more_tests($ipaddr, $port);
  }
  if (!$buffer and $opt_v and $port != 139 and $port != 445) {
    print "No banner, looking if it is HTTP\n" if ($opt_d > 1);
    my $ua = LWP::UserAgent->new;
    $ua->agent("PortScanner/$version (madhat\@unspecific.com)" );
    $ua->timeout($opt_t);
    my $req = HTTP::Request->new(HEAD, "http://$ipaddr:$port/"); 
    my $res = $ua->simple_request($req);
    if (!$res->is_error) {
      $buffer = "Web Server (" . $res->header('Server') . ")"
        if ($res->content or $res->header('Server'));
      $buffer .= "\n" . '-' x 70 . "\n" . $res->content
        if ($res->content and $opt_d > 2);
    } else {
      if ($res->error_as_HTML !~ /timeout|unexpected EOF|Connection reset by peer/) {
        $buffer = "Web Server (" . $res->header("Server") . ") Error: " . $res->code if ($res->content);
      }
      print '-' x 70 . "\n$ipaddr:$port\n" . $res->error_as_HTML . '-' x 70 . "\n" if ($opt_d > 2);
    }
    if (!$buffer) {
      print "STILL No banner, looking if it is HTTPs\n" if ($opt_d > 1);
      my $req = HTTP::Request->new(HEAD, "https://$ipaddr:$port/"); 
      # my $res = $ua->simple_request($req);
      if (!$res->is_error) {
        $buffer = "Web Server (" . $res->header('Server') . ")"
          if ($res->content or $res->header('Server'));
        $buffer .= "\n" . $res->content
          if ($res->content and $opt_d > 2);
      } else {
        if ($res->error_as_HTML !~ /timeout|unexpected EOF|Connection reset by peer/) {
          $buffer = "Web Server (" . $res->header("Server") . 
            ") Error: " . $res->code if ($res->content);
        }
        print '-' x 70 . "\n$ipaddr:$port\n" . $res->error_as_HTML . 
          '-' x 70 . "\n" if ($opt_d > 2);
      }
    }
  }
  if ($buffer) {
    $buffer =~ s/[\n\r]$//g;
    $buffer =~ s/[\n\r]/ /g;
    $buffer =~ s/[^\w\[\]<>:,.'"{}()*&^%$#@!=+\/\\\|\?\s\-]//g;
    $buffer =~ s/</&lt;/g;
    $buffer =~ s/^\s*(.*)\s*$/$1/;
    $output .= " $buffer";
  }
  return $output if ($opt_d > 1 or $open);
}

sub usage{
  print "$0 v$VERSION
MadHat <madhat\@unspecific.com> - http://www.unspecific.com/
     options: < -hs[vP] > \
          -i <filename> |  -l <host_list>\
         [ -o <filename>]\
         [ -t <timeout>]\
         [ -n <num_children>]
         [ -p <port_num>]
         [ -d <debug_level>]\n";
  print "  -h   help (this stuff)\n";
  print "  -v   verbose - will add details (banner grabbing)\n";
  print "  -s   use standard ports (looks for services file in local directory)\n";
  print "  -d   add debuging info (value 1-3)\n";
  print "  -l   network list in comma delimited form: a.b.c.d/M,e.f.g.h/x.y.z.M\n";
  print "  -i   input file containing network list, one network per line\n";
  print "  -n   max number of children to fork\n";
  print "  -p   port number to scan for vulns on\n";
  print "  -P   ping before scanning (ICMP Ping as root, tcp otherwise)\n";
  print "  -t   timeout (in seconds)\n";
  print "  -o   output file\n";
  exit 0;
}


#---------------------------------------
# MAIN STUFF
#---------------------------------------
if ($ENV{'GATEWAY_INTERFACE'} =~ /CGI/) {
  $CGI = 1;
  print header, start_html('YSec Scanner'), "<pre>";
  $| = $CGI;
}

if (!$CGI) {
  getopts("hNPsvd:l:n:t:i:o:p:");
  usage if ( defined($opt_h) );
  usage if ( !(defined($opt_i) xor defined($opt_l)) );
  $opt_n = 16  if ( ! defined($opt_n) );
  $opt_t = 1  if ( ! defined($opt_t) );
} elsif ( param('l') ) {
  $opt_l = param('l');
  $opt_v = param('v') if ( param('v') );
  $opt_d = param('d') if ( param('d') );
  $opt_t = param('t') if ( param('t') );
  $opt_s = param('s') if ( param('s') );
  $opt_N = param('N') if ( param('N') );
  $opt_P = param('P') if ( param('P') );
  $opt_p = param('p');
  $opt_n = 32;
  $opt_l =~ s/\s*//g;
  $date = scalar localtime;
  print STDERR "[$date] Port Scanning $opt_l from $ENV{'REMOTE_ADDR'} by $ENV{'_byuser'}\n";
} else {
  %debug_labels = (''=>'none', '1'=>'Low', '2'=>'Detailed', '3'=>'Annoying');
  print "<h2 align=center>Internal Security Port Scanner</h2><br>",
    "<table>\n",
    start_form, "<tr><td>Host List (see examples below): </td><td>", textfield(-name=>'l', -value=>$ENV{'REMOTE_ADDR'}), "</td></tr>\n",
    "<tr><td>Port to check on each host: </td><td>", textfield(-name=>'p',-value=>'80'), "</td></tr>\n",
    "<tr><td>Timeout for each request (in sec): </td><td>", textfield(-name=>'t', 
    -value=>'2', -size=>'3'), "</td></tr>\n",
    "</table>",
    checkbox(-name=>'N', -label=>'Show NetBIOS name'),br,
    checkbox(-name=>'P', -label=>'Ping before scanning',-checked=>'checked'),br,
    checkbox(-name=>'s', -label=>'Check standard ports'),br,
    checkbox(-name=>'v', -label=>'Verbose output',-checked=>'checked'),br,
    "Debug Level: ", popup_menu(-name=>'d', -values=>['','1','2','3'],
    -labels=>\%debug_labels), br,
    submit('Scan'),
    "<pre>
    Host List Syntax:
       a.b.c.d/n       - 10.0.0.1/25
       a.b.c.*         - 10.0.0.* (0-255) same as /24
       a.b.c.d/w.x.y.z - 10.0.0.0/255.255.224.0 (standard format)
       a.b.c.d/w.x.y.z - 10.0.0.0/0.0.16.255    (cisco format)
       a.b.c.d-z       - 10.1.2.0-12
       a.b.c-x.*       - 10.0.0-3.*  (last octet has to be * or 0)
       a.b.c-x.d       - 10.0.0-3.0
       hostname        - www.unspecific.com
	       
       /30    255.255.255.252        4 IPs
       /29    255.255.255.248        8 IPs
       /28    255.255.255.240       16 IPS
       /27    255.255.255.224       32 IPs
       /26    255.255.255.192       64 IPs
       /25    255.255.255.128      128 IPs
       /24    255.255.255.0        256 IPs
       /23    255.255.254.0        512 IPs
       /22    255.255.252.0       1024 IPs
       /21    255.255.248.0       2048 IPs
       /20    255.255.240.0       4096 IPs
       /19    255.255.224.0       8192 IPs
       /18    255.255.192.0      16384 IPs
       /17    255.255.128.0      32768 IPs
       /16    255.255.0.0        65536 IPs\n\n";
  open (SERV, 'services');
  while (<SERV>) {
    next if (/^\s*$/);
    next if (/^#/);
    next if (/\/udp\s+/);
    print $_;
  }
  close (SERV);
  exit 0;
}


if (defined($opt_o) ){
  open(STDOUT, ">$opt_o") || die ("Cannot open output file $opt_o\n") 
}
select(STDOUT);
&doScan;

while (wait != -1)  { sleep 1 };
print "\n--\nScan Finished.\n";
$end = time;
$timediff = $end - $start;
$timediff = $timediff?$timediff:1;
$ipcount = $#totallist + 1;
$total_count = $total_count?$total_count:0;
print "Scan of $ipcount ip(s) took $timediff seconds\n" if ($opt_v);
print "On $ipcount ip(s), $total_count ports are open\n" if ($opt_v);
printf ("%.1f ips/sec\n", $ipcount/$timediff)  if ($opt_v);

close(STDOUT);

sub calculate_ip_range {
  # written by madhat@unspecific.com
  # what variables are we going to use?
  # take the params
  #   IP, ERR_flasg, max_ip
  # 1st IP scalar
  #  formats allowed include
  #    a.b.c.d/n       - 10.0.0.1/25
  #    a.b.c.*         - 10.0.0.*
  #    a.b.c.d/w.x.y.z - 10.0.0.0/255.255.224.0 (standard format)
  #    a.b.c.d/w.x.y.z - 10.0.0.0/0.0.16.255    (cisco format)
  #    a.b.c.d-z       - 10.1.2.0-12
  #    a.b.c-x.*       - 10.0.0-3.*
  #    a.b.c-x.d       - 10.0.0-3.0
  # 2nd wether or not to return an error message or nothing 
  #    default is to return nothing on error
  # 3rd is max number IPs to return 
  #    default max is 65536 and can not be raised at this time
  my ($ip, $return_error, $max_ip) = @_;
  my @msg = ();
  my $err = '';
  my $port;
  $max_ip = $max_ip || 65536;
  my $a, $b, $c, $d, $sub_a, $sub_b, $sub_c, $sub_d, $num_ip,
      $nm, $d_s, $d_f, $c_s, $c_f, @msg, $err, $num_sub,
      $start_sub, $count_sub;
  # lets start now...
  # does it look just like a single IP address?
  if ($ip =~ s/^(.+):(\d{1,5})/$1/) { $port = $2 }
  if ($ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/) {
    $a = $1; $b = $2; $c = $3; $d = $4;
    if ( $a > 255 or $a < 0 or $b > 255 or $b < 0 or $c > 255 or $c < 0 or 
        $d > 255 or $d < 0) {
      $err = "ERROR: Appears to be a bad IP address ($ip)";
    } else {
      if ($port) { push (@msg, "$ip:$port");
        } else { push (@msg, $ip); }
    }
  # does it look like the format x.x.x.x/n
  } elsif ($ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\/(\d{1,2})$/) {
    $a = $1; $b = $2; $c = $3; $d = $4; $nm = $5;
    if ( $a > 255 or $a < 0 or $b > 255 or $b < 0 or $c > 255 or $c < 0 or 
        $d > 255 or $d < 0 or $nm > 30 or $nm < 0) {
      $err = "ERROR: Something appears to be wrong ($ip)";
    } else {
      $num_ip = 2**(32-$nm);
      if ($num_ip > $max_ip) {
        $err = "ERROR: Too many IPs returned ($num_ip)";
      } elsif ($num_ip <= 256) {
        $num_sub = 256/$num_ip;
        SUBNET: for $count_sub (0..($num_sub - 1)) {
          $start_sub = $count_sub * $num_ip;
          if ($d > $start_sub and $d < ($start_sub + $num_ip)) {
            $d = $start_sub;
            last SUBNET;
          }
        }
        for $d ($d..($d + $num_ip - 1)) {
          $ip = "$a.$b.$c.$d";
          if ($port) { push (@msg, "$ip:$port");
            } else { push (@msg, $ip); }
        }
      } elsif ($num_ip <= 65536) {
        $num_sub = 256/($num_ip/256); $num_ip = $num_ip/256;
        SUBNET: for $count_sub (0..($num_sub - 1)) {
          $start_sub = $count_sub * $num_ip;
          if ($c > $start_sub and $c < ($start_sub + $num_ip)) {
            $c = $start_sub;
            last SUBNET;
          }
        }
        for $c ($c..($c + $num_ip - 1)) {
          for $d (0..255) {
            $ip = "$a.$b.$c.$d";
            if ($port) { push (@msg, "$ip:$port");
              } else { push (@msg, $ip); }
          }
        }
      }
    }
  # does it look like the format x.x.x.x-y
  } elsif ($ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\-(\d{1,3})$/) {
    $a = $1; $b = $2; $c = $3; $d_s = $4; $d_f = $5;
    if ( $d_f > 255 or $d_s > 255 or $d_s < 0 or $d_f < 0 or $a < 0 or 
         $a > 255 or $b < 0 or $b > 255 or $c < 0 or $c > 255 ) {
      $err = "ERROR: Something appears to be wrong ($ip).";
    } elsif ($d_f < $d_s) {
      LOOP: for $d ($d_f .. $d_s) {
        if ($#msg > $max_ip) { 
          $err = "ERROR: Too many IPs returned ($#msg+)"; 
          last LOOP;
        }
        $ip = "$a.$b.$c.$d";
        if ($port) { push (@msg, "$ip:$port");
          } else { push (@msg, $ip); }
      }
      # $err = "Sorry, we don't count backwards.";
    } elsif ($d_f == $d_s) {
      $ip = "$a.$b.$c.$d_s";
      if ($port) { push (@msg, "$ip:$port");
        } else { push (@msg, $ip); }
    } else {
      LOOP: for $d ($d_s .. $d_f) {
        if ($#msg > $max_ip) { 
          $err = "ERROR: Too many IPs returned ($#msg+)"; 
          last LOOP;
        }
        $ip = "$a.$b.$c.$d";
        if ($port) { push (@msg, "$ip:$port");
          } else { push (@msg, $ip); }
      }
    }
  # does it look like the format x.x.x.x-y
  } elsif ($ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\-(\d{1,3})\.(.*)$/) {
    $a = $1; $b = $2; $c_s = $3; $c_f = $4; $d = $5;
    if ( $c_f > 255 or $c_s > 255 or $c_s < 0 or $c_f < 0 or 
         $a < 0 or $a > 255 or $b < 0 or $b > 255 or 
         ( ($d < 0 or $d > 255) and $d ne "*") ) {
      $err = "ERROR: Something appears to be wrong ($ip)";
    } elsif ($c_f < $c_s) {
      LOOP: for $c ($c_f .. $c_s) {
        for $d (0..255) {
          if ($#msg > $max_ip) { 
            $err = "ERROR: Too many IPs returned ($#msg+)"; 
            last LOOP;
          }
          $ip = "$a.$b.$c.$d";
          if ($port) { push (@msg, "$ip:$port");
            } else { push (@msg, $ip); }
        }
      }
    } elsif ($c_f == $c_s) {
      $ip = "$a.$b.$c_s.$d";
      if ($port) { push (@msg, "$ip:$port");
        } else { push (@msg, $ip); }
    } else {
      LOOP: for $c ($c_s .. $c_f) {
        for $d (0..255) {
          if ($#msg > $max_ip) { 
            $err = "ERROR: Too many IPs returned ($#msg+)"; 
            last LOOP;
          }
          $ip = "$a.$b.$c.$d";
          if ($port) { push (@msg, "$ip:$port");
            } else { push (@msg, $ip); }
        }
      }
    }
  # does it look like the format x.x.x.*
  } elsif ($ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.\*$/) {
    $a = $1; $b = $2; $c = $3;
    if ( $a < 0 or $a > 255 or $b < 0 or $b > 255 or $c < 0 or $c > 255 ) {
      $err = "ERROR: Something appears to be wrong ($ip)";
    } else {
      LOOP: for $d (0 .. 255) {
        if ($#msg > $max_ip) { 
          $err = "ERROR: Too many IPs returned ($#msg+)"; 
          last LOOP;
        }
        $ip = "$a.$b.$c.$d";
        if ($port) { push (@msg, "$ip:$port");
          } else { push (@msg, $ip); }
      }
    }
  # does it look like the format x.x.x.x/y.y.y.y
  } elsif ($ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\/(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/) {
    $a = $1; $b = $2; $c = $3; $d = $4; 
    $sub_a = $5; $sub_b = $6; $sub_c = $7; $sub_d = $8;
    # if it appears to be in "cisco" format, convert it
    if ($sub_a == 0 and $sub_b == 0) {
      $sub_a = 255 - $sub_a; $sub_b = 255 - $sub_b;
      $sub_c = 255 - $sub_c; $sub_d = 255 - $sub_d;
    }
    # check to see if the input looks valid
    if ( $a > 255 or $a < 0 or $b > 255 or $b < 0 or $c > 255 or $c < 0 or 
        $d > 255 or $d < 0 or $sub_a > 255 or $sub_a < 0 or
        $sub_b > 255 or $sub_b < 0 or $sub_c > 255 or $sub_c < 0 or 
        $sub_d > 255 or $sub_d < 0 or ($sub_d < 255 and $sub_c != 255 and 
        $sub_b != 255 and $sub_a != 255) or ($sub_d != 0 and 
        $sub_c == 0 and $sub_b < 255 and $sub_a == 255) or 
        ($sub_d != 0 and $sub_c < 255 and $sub_b == 255 and 
        $sub_a == 255)) {
      $err = "ERROR: Something appears to be wrong ($ip)";
      # if it looked valid, but it appears to be an IP, return that IP
    } elsif ($sub_d == 255) {
      $ip = "$a.$b.$c.$d";
      if ($port) { push (@msg, "$ip:$port");
        } else { push (@msg, $ip); }
      # if the range appears to be part of a class C
    } elsif ($sub_d < 255 and $sub_d >= 0 and $sub_c == 255) {
      $num_ip = 256 - $sub_d; $num_sub = 256/$num_ip;
      if ($num_ip > $max_ip) {
        $err = "ERROR: Too many IPs returned ($num_ip)";
      } else {
        SUBNET: for $count_sub (0..($num_sub - 1)) {
          $start_sub = $count_sub * $num_ip;
          if ($d > $start_sub and $d < ($start_sub + $num_ip)) {
            $d = $start_sub;
            last SUBNET;
          }
        }
        LOOP: for $d ($d..($d + $num_ip - 1)) {
          if ($#msg > $max_ip) { 
            $err = "ERROR: Too many IPs returned ($#msg+)"; 
            last LOOP;
          }
          $ip = "$a.$b.$c.$d";
          if ($port) { push (@msg, "$ip:$port");
            } else { push (@msg, $ip); }
        }
      }
    # if the range appears to be part of a class B
    } elsif ($sub_c < 255 and $sub_c >= 0) {
      $num_ip = 256 - $sub_c; $num_sub = 256/$num_ip;
      if ($num_ip > $max_ip) {
        $err = "ERROR: Too many IPs returned ($num_ip)";
      } else {
        SUBNET: for $count_sub (0..($num_sub - 1)) {
          $start_sub = $count_sub * $num_ip;
          if ($c > $start_sub and $c < ($start_sub + $num_ip)) {
            $c = $start_sub;
            last SUBNET;
          }
        }
        LOOP: for $c ($c..($c + $num_ip - 1)) {
          for $d (0..255) {
            if ($#msg > $max_ip) { 
              $err = "ERROR: Too many IPs returned ($#msg+)"; 
              last LOOP;
            }
            $ip = "$a.$b.$c.$d";
            if ($port) { push (@msg, "$ip:$port");
              } else { push (@msg, $ip); }
          }
        }
      }
    }
  } elsif ($ip =~ /[\w\.]+/)  {
    print STDERR "$cli_exec ($$): DNS name $ip\n" if ($opt_d);
    my ($name,$aliases,$type,$len,@thisaddr) = gethostbyname($ip);
    my ($a,$b,$c,$d) = unpack('C4',$thisaddr[0]);
    if ($a and $b and $c and $d) {
      if (calculate_ip_range("$a.$b.$c.$d")) {
        print STDERR "$cli_exec ($$): $ip points to $a.$b.$c.$d\n" if ($opt_d);
        $ip = "$a.$b.$c.$d";
        if ($port) { push (@msg, "$ip:$port");
          } else { push (@msg, $ip); }
      }
    } else {
      $err = "ERROR: Something appears to be wrong ($ip)";
    }

  # if it doesn't match one of those... 
  } else {
    $err = "ERROR: Something appears to be wrong ($ip)";
  }
  if ($err and $return_error) { 
    return "$err\n"; 
  } elsif (@msg) {
    return @msg;
  } else {
    return;
  }
}

sub open_port {
  $total_count++;
}

sub ssh_info {
  %affected = (
    'Unknown', 'unknown',
    'SSH-1.4-1.2.13', 'not affected',
    'SSH-1.4-1.2.14', 'not affected',
    'SSH-1.4-1.2.15', 'not affected',
    'SSH-1.4-1.2.16', 'not affected',
    'SSH-1.5-1.2.17', 'not affected',
    'SSH-1.5-1.2.18', 'not affected',
    'SSH-1.5-1.2.19', 'not affected',
    'SSH-1.5-1.2.20', 'not affected',
    'SSH-1.5-1.2.21', 'not affected',
    'SSH-1.5-1.2.22', 'not affected',
    'SSH-1.5-1.2.23', 'not affected',
    'SSH-1.5-1.2.24', 'affected',
    'SSH-1.5-1.2.25', 'affected',
    'SSH-1.5-1.2.26', 'affected',
    'SSH-1.5-1.2.27', 'affected',
    'SSH-1.5-1.2.28', 'affected',
    'SSH-1.5-1.2.29', 'affected',
    'SSH-1.5-1.2.30', 'affected',
    'SSH-1.5-1.2.31', 'affected',
    'SSH-1.5-1.2.31a', 'not affected', # Custom version post-CORE advisory
    'SSH-1.5-1.2.32', 'not affected',
    'SSH-1.5-1.3.6', 'affected',
    'SSH-1.5-1.3.7', 'affected',
    'SSH-1.5-1.3.8', 'affected',
    'SSH-1.5-1.3.9', 'affected',
    'SSH-1.5-1.3.10', 'affected', # F-Secure SSH versions prior to 1.3.11-2
    'SSH-1.5-Cisco-1.25', 'unknown',
    'SSH-1.5-OSU_1.5alpha1', 'unknown',
    'SSH-1.5-OpenSSH-1.2', 'affected',
    'SSH-1.5-OpenSSH-1.2.1', 'affected',
    'SSH-1.5-OpenSSH-1.2.2', 'affected',
    'SSH-1.5-OpenSSH-1.2.3', 'affected',
    'SSH-1.5-OpenSSH_2.5.1', 'not affected',
    'SSH-1.5-OpenSSH_2.5.1p1', 'not affected',
    'SSH-1.5-OpenSSH_2.9p1', 'not affected',
    'SSH-1.5-OpenSSH_2.9p2', 'not affected',
    'SSH-1.5-RemotelyAnywhere', 'not affected',
    'SSH-1.99-2.0.11', 'affected w/Version 1 fallback',
    'SSH-1.99-2.0.12', 'affected w/Version 1 fallback',
    'SSH-1.99-2.0.13', 'affected w/Version 1 fallback',
    'SSH-1.99-2.1.0.pl2', 'affected w/Version 1 fallback',
    'SSH-1.99-2.1.0', 'affected w/Version 1 fallback',
    'SSH-1.99-2.2.0', 'affected w/Version 1 fallback',
    'SSH-1.99-2.3.0', 'affected w/Version 1 fallback',
    'SSH-1.99-2.4.0', 'affected w/Version 1 fallback',
    'SSH-1.99-3.0.0', 'affected w/Version 1 fallback',
    'SSH-1.99-3.0.1', 'affected w/Version 1 fallback',
    'SSH-1.5-OpenSSH-2.1', 'affected',
    'SSH-1.5-OpenSSH_2.1.1', 'affected',
    'SSH-1.5-OpenSSH_2.2.0', 'affected',
    'SSH-1.5-OpenSSH_2.2.0p1', 'affected',
    'SSH-1.5-OpenSSH_2.3.0', 'not affected',
    'SSH-1.5-OpenSSH_2.3.0p1', 'not affected',
    'SSH-1.5-OpenSSH_2.5.1', 'not affected',
    'SSH-1.5-OpenSSH_2.5.1p1', 'not affected',
    'SSH-1.5-OpenSSH_2.5.1p2', 'not affected',
    'SSH-1.5-OpenSSH_2.5.2p2', 'not affected',
    'SSH-1.5-OpenSSH_2.9.9p2', 'not affected',
    'SSH-1.5-OpenSSH_2.9', 'not affected',
    'SSH-1.5-OpenSSH_2.9p1', 'not affected',
    'SSH-1.5-OpenSSH_2.9p2', 'not affected',
    'SSH-1.5-OpenSSH_3.0p1', 'not affected',
    'SSH-1.5-OpenSSH-2.1', 'affected',
    'SSH-1.99-OpenSSH_2.1.1', 'affected',
    'SSH-1.99-OpenSSH_2.2.0', 'affected',
    'SSH-1.99-OpenSSH_2.2.0p1', 'affected',
    'SSH-1.99-OpenSSH_2.3.0', 'not affected',
    'SSH-1.99-OpenSSH_2.3.0p1', 'not affected',
    'SSH-1.99-OpenSSH_2.5.1', 'not affected',
    'SSH-1.99-OpenSSH_2.5.1p1', 'not affected',
    'SSH-1.99-OpenSSH_2.5.1p2', 'not affected',
    'SSH-1.99-OpenSSH_2.5.2p2', 'not affected',
    'SSH-1.99-OpenSSH_2.9.9p2', 'not affected',
    'SSH-1.99-OpenSSH_2.9', 'not affected',
    'SSH-1.99-OpenSSH_2.9p1', 'not affected',
    'SSH-1.99-OpenSSH_2.9p2', 'not affected',
    'SSH-1.99-OpenSSH_3.0p1', 'not affected',
    );
  return %affected;
}
sub banner_info {
  %banners = (
    'NOTICE \* \:', 'IRC Daemon',
    '^220 Serv-U FTP-Server (\S+)', 'Serv-U FTP',
    '^220 \w+ Microsoft ESMTP MAIL Service, Version: (\S+)', 'Microsoft-SMTP',
    # '^220 .*FTP', 'FTP Daemon',
    # 'SMTP', 'SMTP Daemon',
    'POP3', 'POP3 Daemon',
    'IMAP', 'IMAP Daemon',
  );
  return %banners;
}
sub more_tests {
  print "Testing Port further for info\n" if ($opt_d);
  $/ = CRLF;
  my ($ip, $port) = @_;
  print "Further testing on $ip:$port\n" if ($opt_d);
  my $buffer = $return = '';
  
  print "Testing for ECHO\n" if ($opt_d);
  $buffer = raw_request($ip, $port, "unspecificly echoed");
  $buffer =~ s/\n|\r$//g;
  if ($buffer eq "unspecificly echoed") {
    return "Echo (Really Echoing)";
  }

##########################################################
  print "Testing for Windows Remote Control (Term Serv)\n" if ($opt_d);
  $buffer = raw_request($ip, $port, "\x03\x00\x00\x0b\x06\xe0\x00\x00\x00\x00\x00");
  for (split '', $buffer) {
    $return .= unpack('H*',$_);
  }
  if ($return =~ /^0300000b06d00000123400/) {
    return 'Microsoft Terminal Services';
  }
##########################################################
  print "Testing for LANDesk Remote Control\n" if ($opt_d);
  $buffer = raw_request($ip, $port, "\x54\x4e\x4d\x50\x04\x00\x00\x00\x54\x4e\x4d\x45\x00\x00\x04\x00");
  for (split '', $buffer) {
    $return .= unpack('H*',$_);
  }
  if ($return =~ /^544e4d5004000000544e4d450000feff/) {
    return 'IBM LANDesk Remote Control';
  }
  if ($return =~ /^830000018f830000018f/) {
    return 'NETBIOS Session Service';
  }
  print "$port $return\n" if ($port and $return); # if ($opt_d);
##########################################################

  return $buffer;
}

sub raw_request {
  my ($ip, $port, $senddata) = @_;
  my $buffer;
  eval {
    local $SIG{'__WARN__'};
    local $SIG{'__DIE__'} = "DEFAULT";
    local $SIG{'ALRM'} = sub { die "Timeout Alarm" };
    print STDERR "$cli_exec ($$): Creating Socket to $ip\n" if ($opt_d > 2);
    my $dest_addr = sockaddr_in( $port, inet_aton($ip) );
    socket(SOCK, PF_INET, SOCK_STREAM, getprotobyname('TCP') );
    alarm($opt_t);
    print STDERR "$cli_exec ($$): Connection to RAW Socket\n"
        if ($opt_d > 1);
    connect(SOCK, $dest_addr) or die ($!);
    print STDERR "$cli_exec ($$): Sending Request to $ip\n" if ($opt_d > 2);
    send(SOCK,$senddata,0,$dest_addr);
       # or die "Error: $!";
    print STDERR "$cli_exec ($$): Receiving Data from $ip\n" if ($opt_d > 2);
    recv(SOCK,$buffer,512,0);
      # or die "Error: $!";
    close (SOCK);
    alarm(0);
  };
  return $buffer;

}
sub check_port {
  # sent IP, port, proto('byname') and timeout
  # returns 1 or 0, 1 for open, 0 for not open
  my($ip, $port, $proto, $timeout) = @_;
  $0 = "scanning $ip:$port - PortScan";
  print STDERR "$cli_exec ($$): $ip:$port - PortScan\n"
    if ($opt_d);
  my $p_addr = sockaddr_in($port, inet_aton($ip) );
  my $type;
  my $exitstatus;
  if ($proto =~ /^udp$/i) {
    $type = SOCK_DGRAM;
  } elsif ($proto =~ /^tcp$/i) {
    $type = SOCK_STREAM;
  }
  print STDERR "$cli_exec ($$): creating socket ($ip, $port, $proto)\n"
    if ($opt_d > 1);
  ##################################################################
  eval {
    local $SIG{__WARN__};
    local $SIG{'__DIE__'} = "DEFAULT";
    local $SIG{'ALRM'} = sub { die "Timeout Alarm" };
    socket(TO_SCAN,PF_INET,$type,getprotobyname($proto))
      or die "Error: Unable to open socket: $@";
    alarm($opt_t);
    print STDERR "$cli_exec ($$): connecting to port $port on $ip\n"
      if ($opt_d > 1);
    connect(TO_SCAN, $p_addr)
      or die "Error: Unable to open socket: $@";
    kill USR2, $parent if ($opt_v);
    close (TO_SCAN);
    alarm(0);
  };
  if ($@ =~ /^Error:/) {
    print STDERR "$cli_exec ($$): Unable to connect to $port on $ip\n"
      if ($opt_d > 1);
    $exitstatus = 0;
  } elsif (!$@) {
    print STDERR "$cli_exec ($$): $port on $ip is open\n"
      if ($opt_d > 1);
    $exitstatus = 1;
  }
  ##################################################################
  print STDERR "$cli_exec ($$): Returning ($exitstatus)\n"
    if ($opt_d > 1);
  return($exitstatus);
}
