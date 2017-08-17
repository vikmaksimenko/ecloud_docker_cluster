#!/usr/bin/perl

=head1 NAME

cleanup.pl -- remove containers created for cluster.

=head1 SYNOPSIS

cleanup.pl [arguments] 

=head1 OPTIONS

=over 4

=item B<--help>

Print a brief help message and exit.

=item B<--man>

Print the manual page and exit.

=item B<--containes>

Names of containers to remove

=back

=head1 DESCRIPTION

This script is used to remove containers created by setup.pl script.

Without --containers it will remove ALL containers and network

To remove specified containers run

   $ cleanup.pl --containers slave2 slave3

=head1 AUTHOR

Viktor Maksymenko

=cut

use strict;
use warnings;
use Carp;
use Getopt::Long;
use Pod::Usage;

use Data::Dumper;

my @containers;

#-----------------------------------------------------------------
# OPTIONS
#-----------------------------------------------------------------
GetOptions(
    'help|?' => sub { pod2usage(1) },
    'man'    => sub { pod2usage( -verbose => 2 ) },

    'containers|c=s' 		=> \@containers,

) or pod2usage(2);

if (@containers) {
	@containers = split(/,/,join(',',@containers));
} else {
	open my $handle, '<', "cids.txt";
	chomp(@containers = <$handle>);
	close $handle;
}

while(my $container=shift(@containers)) {
	system("docker kill $container");
	system("docker rm $container")
}

if(system("docker network rm network1") != 0) {
	die "failed to rm network: $?"
}