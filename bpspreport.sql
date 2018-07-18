Rem
Rem $Header: spreport.sql 22-apr-2001.15:44:01 cdialeri Exp $
Rem
Rem spreport.sql
Rem
Rem  Copyright (c) Oracle Corporation 1999, 2000. All Rights Reserved.
Rem
Rem    NAME
Rem      spreport.sql
Rem
Rem    DESCRIPTION
Rem      This script defaults the dbid and instance number to that of the
Rem      current instance connected-to, then calls sprepins.sql to produce
Rem      the standard Statspack report.
Rem
Rem    NOTES
Rem      Usually run as the STATSPACK owner, PERFSTAT
Rem
Rem    MODIFIED   (MM/DD/YY)
Rem Removed a lot of oracle commonts.
Rem Copied and modified for bp customisation.
Rem
Rem   smi425    20180416    Initial copy, take start and end as parameters.

--
-- Get the current database/instance information - this will be used 
-- later in the report along with bid, eid to lookup snapshots

column inst_num  heading "Inst Num"  new_value inst_num  format 99999;
column inst_name heading "Instance"  new_value inst_name format a12;
column db_name   heading "DB Name"   new_value db_name   format a12;
column dbid      heading "DB Id"     new_value dbid      format 9999999999 just c;

prompt
prompt Current Instance
prompt ~~~~~~~~~~~~~~~~

select d.dbid            dbid
     , d.name            db_name
     , i.instance_number inst_num
     , i.instance_name   inst_name
  from v$database d,
       v$instance i;

@@bpsprepins &1 &2

--
-- End of file
