#!/usr/bin/perl

BEGIN {undef $/;}

my $name = $ARGV[0];
my $ip = $ARGV[1];
my $file = $ARGV[2] || "haproxy/haproxy.cfg";

open INFILE, $file or die "Could not open file. $!";
my $string =  <INFILE>;
close INFILE;

$string =~ s/backend commander-stomp-backend(\s*)mode tcp/backend commander-stomp-backend\n        mode tcp\n        server $name $ip:61613 check/sg;
$string =~ s/backend commander-server-backend(\s*)mode http/backend commander-server-backend\n        mode http\n        server $name $ip:8000 check/sg;

open OUTFILE, ">", $file or die "Could not open file. $!";
print OUTFILE ($string);
close OUTFILE;
