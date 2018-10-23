#!/usr/bin/perl

=head1 NAME

runAgent.pl -- Script for running container with agent

=head1 SYNOPSIS

runAgent.pl [arguments] 

=head1 OPTIONS

=over 4

=item B<--help>

Print a brief help message and exit.

=item B<--man>

Print the manual page and exit.

=item B<--agentNumber>

Number of agents to set up

=back

=head1 DESCRIPTION

This script is used to set up agent and connect it to clustered environment in Docker containers. 
It uses custom containers: vmaksimenko/ecloud:slave 

The following command will create 3 agents:

   $ runAgent.pl --agentNumber 3

If there are already created agents in system, it will run 3 MORE agents

=head1 AUTHOR

Viktor Maksymenko

=cut

use strict;
use warnings;
use Carp;
use Getopt::Long;
use Pod::Usage;

use Data::Dumper;

#-----------------------------------------------------------------
# Command line variables
#-----------------------------------------------------------------

my $agent_number  = 1;
my $commander_dir   = "/opt/electriccloud/electriccommander";
my $server_ip;

my $current_dir = `pwd`;
chomp($current_dir);

my $cmd;
my $out;

my $cid;
my $ip;


#-----------------------------------------------------------------
# OPTIONS
#-----------------------------------------------------------------
GetOptions(
    'help|?' => sub { pod2usage(1) },
    'man'    => sub { pod2usage( -verbose => 2 ) },
    'agentNumber|a=i'   => \$agent_number
) or pod2usage(2);


# TODO: Move utils subs to separate modules

sub get_container_ip {
  my $container = shift;
  my $out = `docker inspect $container`;

  $out =~ /"IPAddress": "(\d+\.\d+\.\d+\.\d+)"/;
  $ip = $1;
  return $ip;
}

sub get_logging_time {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    my $nice_timestamp = sprintf ("%04d/%02d/%02d %02d:%02d:%02d",
                                   $year + 1900, $mon+1, $mday, $hour, $min, $sec);
    return $nice_timestamp;
}

sub echo {
  my $message = shift;
  my $timestamp = get_logging_time();
  print("[$timestamp] $message\n");
}

sub validate_container {
  my ($container, $cid) = @_;
  my $out = `docker inspect $cid`;
  die "ERROR: $container is not running. CID: $cid" if( $out !~ /"Running": true/ );
}

sub serialise_docker_instance {
  my ($name, $type, $cid) = @_;
  my $filename = 'instances.csv';

  open(my $fh, '>>', $filename) or die "ERROR: Failed to open '$filename' $!";
  print $fh "$name,$type,$cid\n";
  close $fh;
}

sub run {
  my $cmd = shift;
  system($cmd) == 0 or die qq{system "$cmd" failed: $?};
}

# Get Haproxy/Slave IP
$out = `docker ps`;

if ($out =~ /haproxy/) {
  $server_ip = get_container_ip("haproxy");
} elsif ($out =~ /slave1/) {
  $server_ip = get_container_ip("slave1");
} else {
  die "There's no haproxy or slave container. Run some or provide server ip";
}


# Get number of existing agents: 
my $existing_agent_num = `docker ps | grep -c agent` + 0;
echo("There are $existing_agent_num agents already setup. Adding $agent_number more");

for (my $i = 1; $i <= $agent_number; $i++) {
  my $agent = "agent" . ($i + $existing_agent_num);
  echo("Creating $agent");
  $cid = `docker run -dit --name $agent --net network1 --hostname $agent --volume $current_dir/slave:/data --volume workspace:/workspace --volume plugins:/plugins vmaksimenko/ecloud:slave`;
  validate_container($agent, $cid);
  run(qq{docker exec -it $agent /data/install_agent.sh $server_ip});
}


# # system("/data/Electric* --mode silent --installAgent --unixAgentGroup build --unixAgentUser build") or die "Installation failed!";
# print(system("/data/Electric* --mode silent --installAgent --unixAgentGroup build --unixAgentUser build") );
# system("$ectool --server $serverIp login admin changeme");
# system("$ectool --server $serverIp deleteResource $(hostname)");
# system("$ectool --server $serverIp createResource $(hostname) --hostName $(hostname) --port 7800 --resourcePools local,default");
# system("$commander_dir/bin/ecconfigure --agentPluginsDirectory '/plugins'");
