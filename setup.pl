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

What database to use for cluster setup. Can be one of: {MYSQL,ORACLE,MSSQL}

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
my @db_types 		= ("MYSQL", "ORACLE", "MSSQL");
my $commander_dir 	= "/opt/electriccloud/electriccommander";

my $current_dir = `pwd`;
chomp($current_dir);

my $cmd;
my $out;

my $cid;
my $ip;

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

	serialise_docker_instance($container, "container", $cid);

	die "ERROR: $container is not running. CID: $cid" if( $out !~ /"Running": true/ );

	my $ip = get_container_ip($cid);

	$containers{$container} = {
	    "cid"	=> $cid,
	    "ip"	=> $ip
	};
}

sub serialise_docker_instance {
	my ($name, $type, $cid) = @_;
	my $filename = 'instances.csv';

	open(my $fh, '>>', $filename) or die "ERROR: Failed to open '$filename' $!";
	print $fh "$name,$type,$cid\n";
	close $fh;
}

sub update_database_properties {
	my ($db_ip, $db_type) = @_;
	$db_type = lc($db_type);

	my $dest = "slave/database.properties";
	my $src = "slave/database.properties-$db_type";

	run("cp $src $dest");
	run("sed -i.bak 's/IP/$db_ip/' $dest");
}

# Check that installer, license and mysql-connector are present in slave directory
sub check_files {
	run("find $current_dir/slave/Electric* > /dev/null");
	run("find $current_dir/slave/mysql-connector* > /dev/null");
	run("find $current_dir/slave/license.xml > /dev/null");
}

check_files();

# echo("Creating network");
# $cid = `docker network create -d bridge network1`;
# chomp($cid);
# serialise_docker_instance("network1", "network", $cid);

# echo("Creating volume for workspace");
# $out = `docker volume create --name workspace`;
# chomp($out);
# serialise_docker_instance($out, "volume", $out);

# echo("Creating volume for plugins");
# $out = `docker volume create --name plugins`;
# chomp($out);
# serialise_docker_instance($out, "volume", $out);


# # TODO: REFACTOR THIS CODE BLOCK
# echo("Starting $db_type database server");
# if ($db_type eq "MYSQL") {
# 	$cid = `docker run -d --name db --net network1 --hostname db --env MYSQL_ROOT_PASSWORD=root --env MYSQL_DATABASE=commander --publish 3306:3306 -v $current_dir/db/mysql:/etc/mysql/conf.d mysql:latest`;
# } elsif($db_type eq "ORACLE") {
# 	$cid = `docker run -d --name db --net network1 --hostname db --env ORACLE_ALLOW_REMOTE=true --publish 49160:22 --publish 49161:1521 -v $current_dir/db/oracle:/data wnameless/oracle-xe-11g`;
# } elsif($db_type eq "MSSQL") {
# 	$cid = `docker run -d --name db --net network1 --hostname db --env 'ACCEPT_EULA=Y' --env 'SA_PASSWORD=Comm\@nder' --publish 1433:1433 -v $current_dir/db/mssql:/data microsoft/mssql-server-linux`;
# }

# chomp($cid);
# validate_container("db", $cid);

# if($db_type eq "ORACLE") {
# 	run("docker exec -it db sh /data/update_db_server.sh");
# } elsif($db_type eq "MSSQL") {
# 	echo("Waiting for MSSQL server up");
# 	system("sleep 90");
# 	run("docker exec -it db /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P Comm\@nder -d master -i /data/setup.sql");
# }

# echo("Updating database.properties");
# update_database_properties($containers{"db"}{"ip"}, $db_type);

# echo("Creating $slave_number slaves");
# for (my $i = 1; $i <= $slave_number; $i++ ) {
# 	echo("Starting slave$i");
# 	$cid = `docker run --name slave$i --net network1 --hostname slave$i --volume $current_dir/slave:/data --volume workspace:/workspace --volume plugins:/plugins -dit vmaksimenko/ecloud:slave`;
# 	chomp($cid);
# 	validate_container("slave$i", $cid);
# 	system(qq{perl update_haproxy_cfg.pl slave$i $containers{"slave$i"}{"ip"}});
# }

# echo("Run Zookeeper Server");
# $cid = `docker run -d --name zookeeper --net network1 --hostname zookeeper --publish 8080:8080 --volume $current_dir/exhibitor:/exhibitor jplock/zookeeper`;
# chomp($cid);
# validate_container("zookeeper", $cid);

# echo("Starting Exhibitor");
# run("docker exec -d zookeeper java -jar /exhibitor/exhibitor-1.5.5.jar -c file");

# echo("Run Haproxy server container");
# $cid = `docker run -dit --name haproxy --hostname haproxy --net network1 --publish 1936:1936 --volume $current_dir/haproxy:/data vmaksimenko/ecloud:haproxy`;
# validate_container("haproxy", $cid);

# echo("Create server certificate");
# run("docker exec -it haproxy perl /data/generate_certificate.pl > /dev/null");

# echo("Starting haproxy service");
# run("docker exec -it haproxy sudo cp /data/haproxy.cfg /etc/haproxy/haproxy.cfg");
# run("docker exec -it haproxy /etc/init.d/haproxy start > /dev/null");

# echo("Install commander on slaves");
# for (my $i = 1; $i <= $slave_number; $i++ ) {
# 	echo("Installing commander to slave$i");
# 	run("docker exec -it slave$i sudo /data/install_commander.sh");
# }

# echo("Move first node to cluster");
# run(qq{docker exec -it slave1 sudo /data/setup_master.sh $containers{"haproxy"}{"ip"} $containers{"zookeeper"}{"ip"} $db_type});

echo("Move other nodes to cluster");
for (my $i = 2; $i <= $slave_number; $i++ ) {
	echo("Moving slave$i");
	run(qq{docker exec -it slave$i $commander_dir/bin/ecconfigure --serverName $containers{"zookeeper"}{"ip"} --serverZooKeeperConnection $containers{"zookeeper"}{"ip"}:2181});
}
for (my $i = 2; $i <= $slave_number; $i++ ) {
	echo("Waiting for slave$i");
	run("docker exec -it slave$i sudo /data/wait_for_server.sh");
}

echo("Creating Web Server");
$cid = `docker run -dit --name web --net network1 --hostname web --volume $current_dir/slave:/data --volume workspace:/workspace --volume plugins:/plugins --publish 443:443 vmaksimenko/ecloud:slave`;
validate_container("web", $cid);
run(qq{docker exec -it web sudo /data/install_web.sh $containers{"haproxy"}{"ip"}});

echo("Creating agent");
$cid = `docker run -dit --name agent --net network1 --hostname agent --volume $current_dir/slave:/data --volume workspace:/workspace --volume plugins:/plugins vmaksimenko/ecloud:slave`;
validate_container("agent", $cid);
run(qq{docker exec -it agent sudo /data/install_agent.sh $containers{"haproxy"}{"ip"}});

