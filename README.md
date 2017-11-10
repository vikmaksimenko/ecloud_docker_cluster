# ECloud Docker Cluster

This project bootstraps Commander clustered environment on Docker container. 

## How to:

1. Install Docker 
2. Download or clone this project
3. Put Commander installer and license.xml to **slave** directory 
4. If you're going to use MySQL database, put [MySQL JDBC connector](http://dev.mysql.com/downloads/connector/j/) to **slave** directory  
5. The following ports should be available:
    * 3306 (for MySQL server)
    * 22, 1521 (for Oracle Database Server)
    * 1433 (for MSSQL server)
    * 1936 (for Haproxy)
    * 8080 (for ZooKeeper)
    * 443 (for Web server)
3. Run `setup.pl` with following parameters:
    * **--man** - Print the manual page and exit.
    * **--help** - Print a brief help message and exit.
    * **--dbType** - What database to use for cluster setup. Can be one of:
        MYSQL, ORACLE, MSSQL
    * **--slaveNumber** - Number of slaves to set up
    * **--agentNumber** - Number of agents to set up
    
## Cluster Structure
* Docker Network
* Docker Volumes for workspace and plugins
* Haproxy server
* ZooKeeper server 
* Database server 
* Slaves
* Web Server
* Agents

### Docker Network 
All containers run on same [Docker bridge network](https://docs.docker.com/engine/userguide/networking/#bridge-networks). It allows containers to communicate. The following ports are forwarded from containers:
* 3306 (MySQL Database server) 
* 22, 1521 (Oracle Database Server)
* 1433 (MSSQL)
* 1936 (Haproxy)
* 8080 (ZooKeeper)
* 443 (Web server)

### Docker Volumes
For sharing data between containers we create [Docker Volumes](https://docs.docker.com/engine/admin/volumes/volumes/) for workspace and plugins directories. 

### Haproxy Server
For running Haproxy we set up custom [image](https://hub.docker.com/r/vmaksimenko/ecloud). Docker file (**Dockerfile-haproxy**) is in  **dockerfiles** directory. **haproxy** directory is mounted into **/data** directory. Container forwards 1936 port to 1936 host's port. 

### ZooKeeper Server
We use [zookeeper image](https://hub.docker.com/r/jplock/zookeeper/) from DockerHub to set up container. **exhibitor** directory is mounted into **/exhibitor** directory. Container forwards 8080 port to 8080 host's port. Also, after container bootstrap [Exhibitor](https://github.com/soabase/exhibitor) is installed and ran on container. It allows to view data, stored in ZooKeeper

### Database Server
Cluster can be set up with MySQL, Oracle or MSSQL DB server. 

#### MySQL
For running cluster with MySQL you have to put [MySQL JDBC connector](http://dev.mysql.com/downloads/connector/j/) to **slave** directory. We use latest [MySQL image](https://hub.docker.com/r/library/mysql/) from DockerHub to set up container. For connecting commander we set MYSQL_ROOT_PASSWORD to **root** and create database **commander**. **db/mysql** folder will be mounted into **/etc/mysql/conf.d**. Fill free to modify **my.cnf** file for reconfiguring MySQL server. Container forwards 3306 port to 3306 hosts port.

#### Oracle
We use [Oracle XE 11g image](https://hub.docker.com/r/wnameless/oracle-xe-11g/) from DockerHub to set up container. Container forwards 49160 port to 22 host's port and 49161 port to 1521 host's port.

#### MSSQL
We use [MSSQL linux image](https://hub.docker.com/r/microsoft/mssql-server-linux/) from DockerHub to set up container. SA_PASSWORD is "Comm@nder". Container forwards 1433 port to 1433 host's port.

### Slaves
For running slaves we set up custom [image](https://hub.docker.com/r/vmaksimenko/ecloud). Docker file (**Dockerfile-slave**) is in  **dockerfiles** directory. **slave** directory is mounted into **/data** directory, **workspace** and **plugins** volumes are mounted into **/workspace** and **/plugins**. After running slaves we update **haproxy.cfg** file with proper slave IP.
The first slave will become a master node, the one, that will be used for publishing config files into ZooKeeper server. Other nodes will use that files.

### Web Server and Agent
Web server and agents are much similar to slaves, but use other provision scripts. Web server forwards 443 port to 443 host's port 

## Clean Up
For removing containers run `cleanup.pl`. It will stop and remove all created containers, volumes and network. Run

## TBD

* Add Web Server clustering
* Refactor `setup.pl` script to "Infrastructure as a code" way
* Add Windows support


