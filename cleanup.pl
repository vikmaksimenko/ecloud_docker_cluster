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

=item B<--containers>

Names of containers to remove

=item B<--networks>

Names of networks to remove

=item B<--volumes>

Names of volumes to remove

=item B<--file>

Path to CSV file with instance name, type and cid in format "$name,$type,$cid". Type can be one of {container, volume, network}

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
my @volumes;
my @networks;

my $file = "instances.csv";

#-----------------------------------------------------------------
# OPTIONS
#-----------------------------------------------------------------
GetOptions(
    'help|?' => sub { pod2usage(1) },
    'man'    => sub { pod2usage( -verbose => 2 ) },

    'containers|c=s' 		=> \@containers,
	'networks|n=s' 			=> \@networks,
	'volumes|v=s'	 		=> \@volumes,
	'file|f=s'				=> \$file,
) or pod2usage(2);

sub read_csv {
	my $file = shift;
	my %instances;

	open(my $data, '<', $file) or die "Could not open '$file' $! ==== \n";
 
	while (my $line = <$data>) {
  		chomp $line;
   		next if(!$line);

  		my @fields = split("," , $line);
		$instances{$fields[0]} = {
			"name"	=> $fields[0],
			"type"	=> $fields[1],
			"cid"	=> $fields[2]
		};
	}

	return %instances;
}

sub remove_container {
	my $name = shift;
	print( qq{==== Removing container: $name ==== \n} );
	system("docker kill $name");
	system("docker rm $name")
}

sub remove_network {
	my $name = shift;
	print( qq{==== Removing network: $name ==== \n} );
	system("docker network rm $name");
}

sub remove_volume {
	my $name = shift;
	print( qq{==== Removing volume: $name ==== \n} );
	system("docker volume rm $name");
}

my %instances = read_csv($file);

if (@containers) {
	@containers = split(/,/,join(',',@containers));
	for my $container (@containers) {
		if($instances{$container}) {
			remove_container($instances{$container}{"name"});
		}
	}
} 

if (@networks) {
	@networks = split(/,/,join(',',@networks));
	for my $network (@networks) {
		if($instances{$network}) {
			remove_network($instances{$network}{"name"});
		}
	}
}

if (@volumes) {
	@volumes = split(/,/,join(',',@volumes));
	for my $volume (@volumes) {
		if($instances{$volume}) {
			remove_volume($instances{$volume}{"name"});
		}
	}
}

if (!@containers && !@volumes && !@networks) {
	# Splitting hash to 3 arrays
	my (@containers, @volumes, @networks);

	while ((my $name, my $instance) = each %instances ) {
		my %instance = %instances{$name};

	    if ($instance->{"type"} eq "container") {
			push @containers, $instance;
		} elsif($instance->{"type"} eq "volume")	{
			push @volumes, $instance;
		} elsif($instance->{"type"} eq "network") {
			push @networks, $instance;
		}
	}

	# Network and Volume can be removed only if they are not in use by container 
	for my $container (@containers) {
		remove_container($container->{"name"});
	}

	for my $volume (@volumes) {
		remove_volume($volume->{"name"});
	}

	for my $network (@networks) {
		remove_network($network->{"name"});
	}
}

# Cleanup cid file
system("> instances.csv");

# Cleanup haproxy.cfg
system("cp haproxy/haproxy.cfg.sample haproxy/haproxy.cfg");
