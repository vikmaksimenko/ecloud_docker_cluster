#!/usr/bin/perl

=head1 NAME

setup.pl -- Set up Commander server cluster on Docker container.

=head1 SYNOPSIS

setup.pl [arguments] 

=head1 OPTIONS

=over 4

=item B<--help>

Print a brief help message and exit.

=item B<--man>

Print the manual page and exit.

=item B<--dbType>

What database to use for cluster setup. Can be one of: MYSQL

=item B<--slaveNumber>

Number of slaves to set up

=item B<--agentNumber>

Number of agents to set up

=back

=head1 DESCRIPTION

This script is used to set up cluster environment in Docker containers. 
It uses mysql:latest, jplock/zookeeper for database and zookeeper.
Also it uses custom containers: vmaksimenko/ecloud:slave 
and vmaksimenko/ecloud:haproxy.

The following command will create 3-node cluster with 3 agents:

   $ setup.pl --dbType MYSQL --slaveNumber 3 --agentNumber 3

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

my $slave_number	= 1;
my $agent_number	= 1;
my $db_type			= "MYSQL";
my @db_types 		= ("MYSQL", "ORACLE");
my $commander_dir 	= "/opt/electriccloud/electriccommander";

my $current_dir = `pwd`;
chomp($current_dir);

my $cmd;
my $out;

my $cid;
my $ip;
my %slave;

my @slaves;
my $db_cid;
my $haproxy_cid;
my $zk_cid;
my $web_cid;
my $agent_cid;

my %containers;

#-----------------------------------------------------------------
# OPTIONS
#-----------------------------------------------------------------
GetOptions(
    'help|?' => sub { pod2usage(1) },
    'man'    => sub { pod2usage( -verbose => 2 ) },

    'slaveNumber|s=i' 		=> \&validate_slave_number,
    'agentNumber|a=i'		=> \$agent_number,
    'dbType|d=s'			=> \&validate_db
) or pod2usage(2);

sub validate_db {
	my ($opt_name, $opt_value) = @_;

	for( @db_types ){
		if( $opt_value eq $_ ) {
			$db_type = $opt_value;
			return;
		}
	}
	die "Unknown database type $opt_value. Allowed: @db_types";
}

sub validate_slave_number {
	my ($opt_name, $opt_value) = @_;
	die "Slave number should be greater then 0" if ($opt_value < 1);
	$slave_number = $opt_value;
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

sub run {
	my $cmd = shift;
	system($cmd) == 0 or die qq{system "$cmd" failed: $?};
}

sub get_container_ip {
	my $cid = shift;
	my $out = `docker inspect $cid`;

	$out =~ /"IPAddress": "(\d+\.\d+\.\d+\.\d+)"/;
	$ip = $1;
	return $ip;
}

sub validate_container {
	my ($container, $cid) = @_;
	my $out = `docker inspect $cid`;

	die "ERROR: $container is not running. CID: $cid" if( $out !~ /"Running": true/ );

	my $ip = get_container_ip($cid);

	$containers{$container} = {
	    "cid"	=> $cid,
	    "ip"	=> $ip
	};

	my $filename = 'cids.txt';
	open(my $fh, '>>', $filename) or die "ERROR: Failed to open '$filename' $!";
	print $fh $cid;
	close $fh;
}

sub update_database_properties {
	my $db_ip = shift;

	my $dest = "slave/database.properties";
	my $src = "slave/database.properties-mysql";

	run("cp $src $dest");
	run("sed -i.bak 's/IP/$db_ip/' $dest");
}

# Check that installer, license and mysql-connector are present in slave directory
sub check_files {
	run("find $current_dir/slave/Electric* > /dev/null");
	run("find $current_dir/slave/mysql-connector* > /dev/null");
	run("find $current_dir/slave/license.xml > /dev/null");
}

sub create_haproxy_cfg {
	my $buffer;
	my $config = <<'END_CONFIG';
# This config needs haproxy-1.1.28 or haproxy-1.2.1

global 
        log 127.0.0.1   local0
        log 127.0.0.1   local1 notice
        #log loghost    local0 info
        maxconn 20000
        #chroot /usr/share/haproxy
        user haproxy
        group haproxy
        daemon
        #debug
        #quiet

defaults
        log     global
        option  dontlognull
        retries 3
        option redispatch
        maxconn 20000
        contimeout      5000
        clitimeout      50000
        srvtimeout      50000

listen stats *:1936
       mode http
       stats enable
       stats realm Haproxy\\ Statistics
       stats uri /
       stats refresh 30
       stats show-legends


# load balance ports 8000 and 8443 across Commander servers, with HAProxy acting as the SSL endpoint for port 8443, and health check HTTP GET /commanderRequest/health

frontend commander-server-frontend-insecure
        mode http
        bind 0.0.0.0:8000
        default_backend commander-server-backend

frontend commander-server-frontend-secure
        mode tcp
        bind 0.0.0.0:8443 ssl crt /var/tmp/server.pem
        default_backend commander-server-backend

backend commander-server-backend
        mode http
END_CONFIG

	for (my $i = 1; $i <= $slave_number; $i++ ) {
		my $key = "slave$i";
		$config = qq{$config\tserver node$i $containers{$key}{"ip"}:8000 check\n};
	}

	$buffer = <<'END_CONFIG';
        stats enable
        option httpchk GET /commanderRequest/health

# load balance port 61613 across Commander servers, with HAProxy acting as the SSL endpoint

frontend commander-stomp-frontend
        mode tcp
        bind 0.0.0.0:61613 ssl crt /var/tmp/server.pem
        default_backend commander-stomp-backend
        option tcplog
        log global

backend commander-stomp-backend
        mode tcp
END_CONFIG

	$config = $config . "\n" . $buffer;

	for (my $i = 1; $i <= $slave_number; $i++ ) {
		my $key = "slave$i";
		$config = qq{$config\tserver node$i $containers{$key}{"ip"}:61613 check\n};
	}

	$buffer = <<'END_CONFIG';
        option tcplog
        log global
END_CONFIG

	$config = $config . "\n" . $buffer;
}

# Cleanup cid file
run("> cids.txt");

check_files();

echo("Creating network");
$cid = `docker network create -d bridge network1`;

echo("Starting $db_type database server");
$cid = `docker run -d --name db --net network1 --hostname db --env MYSQL_ROOT_PASSWORD=root --env MYSQL_DATABASE=commander --publish 3306:3306 mysql:latest`;
validate_container("db", $cid);

echo("Updating database.properties");
# TODO: add support of all the required db types
update_database_properties($containers{"db"}{"ip"});

echo("Creating $slave_number slaves");
for (my $i = 1; $i <= $slave_number; $i++ ) {
	echo("Starting slave$i");
	$cid = `docker run --name slave$i --net network1 --hostname slave$i --volume $current_dir/slave:/data -dit vmaksimenko/ecloud:slave`;
	validate_container("slave$i", $cid);
}

echo("Run Zookeeper Server");
$cid = `docker run -d --name zookeeper --net network1 --hostname zookeeper jplock/zookeeper`;
validate_container("zookeeper", $cid);

echo("Create haproxy.cfg file");
my $haproxy_cfg = create_haproxy_cfg();
my $filename = 'haproxy/haproxy.cfg';
open(my $fh, '>', $filename) or die "ERROR: Failed to open '$filename' $!";
print $fh $haproxy_cfg;
close $fh;

echo("Run Haproxy server container");
$cid = `docker run -dit --name haproxy --hostname haproxy --publish 1936:1936 --volume $current_dir/haproxy:/data vmaksimenko/ecloud:haproxy`;
validate_container("haproxy", $cid);

echo("Create server certificate");
run("docker exec -it haproxy perl /data/generate_certificate.pl > /dev/null");

echo("Starting haproxy service");
run("docker exec -it haproxy sudo cp /data/haproxy.cfg /etc/haproxy/haproxy.cfg");
run("docker exec -it haproxy /etc/init.d/haproxy start > /dev/null");

echo("Install commander on slaves");
for (my $i = 1; $i <= $slave_number; $i++ ) {
	echo("Installing commander to slave$i");
	run("docker exec -it slave$i sudo /data/install_commander.sh");
}

echo("Move first node to cluster");
run(qq{docker exec -it slave1 sudo /data/setup_master.sh $containers{"haproxy"}{"ip"} $containers{"zookeeper"}{"ip"}});

echo("Move other nodes to cluster");
for (my $i = 2; $i <= $slave_number; $i++ ) {
	run(qq{docker exec -it slave$i $commander_dir/bin/ecconfigure --serverName $containers{"zookeeper"}{"ip"} --serverZooKeeperConnection $containers{"zookeeper"}{"ip"}:2181});
}
for (my $i = 2; $i <= $slave_number; $i++ ) {
	run("docker exec -it slave$i sudo /data/wait_for_server.sh");
}

echo("Creating Web Server");
$web_cid = `docker run -dit --name web --net network1 --hostname web --volume $current_dir/slave:/data --publish 443:443 vmaksimenko/ecloud:slave`;
run(qq{docker exec -it web sudo /data/install_web.sh $containers{"haproxy"}{"ip"}});

echo("Creating agent");
$agent_cid = `docker run -dit --name agent --net network1 --hostname agent --volume $current_dir/slave:/data vmaksimenko/ecloud:slave`;
run(qq{docker exec -it web sudo /data/install_agent.sh $containers{"haproxy"}{"ip"}});

