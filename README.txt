0   Overview
1   Package Contents
2   Prerequisites
3   Installation
4   Usage

0   Overview

    This utility extracts AWR reports in bulk from an oracle database. It
    creates one report per snapshot interval. e.g 201-202 202-203 203-204 etc.
    
    It will extract either -
        all reports currently in the AWR ( RECYCLE_SNAPSHOTS=Y ); or
        all reports since the last run. This is achieved using the last snapshot
         number in the properties file.
         
    It will run against all databases defined in the properties file.
    
    It can be used to extract reports for a given database from an RMAN copy of
    that database. An RMAN copy of a PROD database will still contain snapshots
    for the PROD database.
    
1   Package Contents

1.1 Package zip file.
    The package zip file contains 3 other zip files
        - the 2 instant client zip files
        - the utility script zip file awrbulk_sa_<ver>
        
1.2 Oracle Instant client
    
    There are two instant client zipfiles
        instantclient-basic-linux.x64-12.1.0.2.0
        instantclient-sqlplus-linux.x64-12.1.0.2.0
    These can be replaced with the other versions or architectures if required.
    Instant client can be downloaded free from otn.oracle.com (an OTN account is
    needed)
    
1.3 Instant client configuration scripts
    
        sqlnet.ora

1.4 Utility Scripts
    
        awrinpnm.sql                    Oracle awr report script
        awrinput.sql                    Oracle awr report script
        awrreport.env                   Utility environment file
        awrrpt.properties               Utility configuration file
        awrrpt_bulk.sh                  Utility bulk report extract
        awrrpt_collect.sh               Utility master file.
        awrrpt_get_snapshot_range.sql   Utility script to get awr details
        awrrpti.sql                     Oracle awr report script
        awr_reporter_role.sql           Utility script to create reporter role
        awr_user.sql                    Utility script to create an awr user.
        
2.  Prerequisites

2.1 Database Account.

    This utility requires an oracle database account on each target database
    which has privileges to run the AWR report utilities.
    
    The required privileges are
    
        SELECT ON SYS.V_$DATABASE
        SELECT ON SYS.V_$INSTANCE
        EXECUTE ON SYS.DBMS_WORKLOAD_REPOSITORY
        SELECT ON SYS.DBA_HIST_DATABASE_INSTANCE
        SELECT ON SYS.DBA_HIST_SNAPSHOT
        SELECT ON SYS.WRM$_DATABASE_INSTANCE
        SELECT ON SYS.WRM$_SNAPSHOT
    
    Scripts to create a role with these privileges and a user with the required
    role are included in the package. A DBA is needed to create the role and user.
        
2.2 Write access to the destination directory.

    The default destination directory is
    /net/reuxeuss017-f01/vol/s17_f01_shared/q_s17_f01_shared/AWRrepo but this can
    be replace if necessary.
        
        
3   Installation

    Extract the three zip files from the master zip.
    
3.1 Install Oracle Instant Client
    
    Choose a suitable location (e.g. /opt/oracle)
    Unzip both instant client zip files into the same location.
    THis will create a directory /opt/oracle/instantclient_12_1. THis is ORACLE_HOME.

3.2 Install the utility Scripts
    
    Choose a suitable location for the scripts (e.g. /opt/awrbulk)
    Unzip awrbulk_sa_<ver>.zip into this location.
    
3.3 Configure Instant Client
    
    Copy the sqlnet.ora file from utility script directory into ORACLE_HOME   

3.4 Configure the Utility Scripts
    There are two files which neede to be edited. There are further explanations
    in the files themselves.
    
3.4.1    awrrpt.env
    
    ORACLE_HOME=<Location of instant client>
    ORACLE_LIB=<Location of instant client> # Whether this is required seems to vary by operating system.
    RECYCLE_SNAPSHOTS=Y|N
    DEFAULT_PROPERTIES=awrrpt.properties
    REPORT_LOCATION=<location to copy report files to>
    
3.4.2    awrrpt.properties ( or another property file)

 There are three record types.
 DEF: defines the database name and snaphot collection details.
 The fields are
   record type             DEF
   database to report on    - UPPER CASE
   database to report from  - name must match the instance name 
   last snapshot reported   - start at 1 for a new collection
   timestamp of last collection

 URL:   EZCONNECT  connection component details.
 The fields are
   record type             URL
   database key    - should match a key from a DEF record
   hostname
   port
   service name.

 These are used to form a connect string of the form
    @host:port/service_name

 CON:  credentials for the database connection
 The fields are
   record type             URL
   database key    - should match a key from a DEF record
   username 
   password
        
4   Usage

$ cd <install_directory>
$ ./awrrpt_collection.sh [properties file]

The properties file parameter is optional. If it is omitted, the default
properties file specified in awrrpt.env is used.

A single run of the script will loop through all the databases defined
in the properties file and for each database
    determine the snapshot range
    extract all reports for the snapshot range to the local directory
    zip and remove all the report files
    move the zip file to a database specific directory in the report repository.
    

