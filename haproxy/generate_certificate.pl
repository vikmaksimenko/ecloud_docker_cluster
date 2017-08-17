#!/usr/bin/perl

my $cnf = "/etc/ssl/openssl.cnf";

my $hostname = `hostname`;
chomp($hostname);

my $ip = `/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print \$1}'`;
chomp($ip);

# Backup default openssl.cnf file
system("cp $cnf $cnf.bak");

# Update it according to http://wiki/display/ec/Win+Server+2012+cluster+configuration#WinServer2012clusterconfiguration-Createservercertificate
open(FILE, "<$cnf") || die "File $cnf not found";
my @lines = <FILE>;
close(FILE);

my @newlines;
foreach(@lines) {
	$_ =~ s/# copy_extensions = copy/copy_extensions = copy/g;
	$_ =~ s/# req_extensions = v3_req/req_extensions = v3_req/g;

	my $snippet = <<"SNIPPET";
subjectAltName = \@alt_names

[ alt_names ]

DNS.1 = $hostname
IP.1 = $ip

[ v3_ca ]
SNIPPET

	$_ =~ s/\[ v3_ca \]/$snippet/g;

	push(@newlines,$_);
}

open(FILE, ">$cnf") || die "File $cnf not found";
print FILE @newlines;
close(FILE);

# Generate certificate
`openssl req -x509 -nodes -newkey rsa:2048 -keyout key.pem -out cert.pem -days 3650 -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com"`;
`cat cert.pem key.pem > /var/tmp/server.pem`;
