set echo off
Rem
Rem $Header: rdbms/admin/awrrpti.sql /st_rdbms_11.2.0/1 2011/07/25 11:37:43 shiyadav Exp $
Rem
Rem awrrpti.sql
Rem
Rem Copyright (c) 2001, 2011, Oracle and/or its affiliates. 
Rem All rights reserved. 

set echo off;

set veri off;
set feedback off;
set termout off;

set termout off;
-- set report function name and line size
column fn_name new_value fn_name noprint;
select 'awr_report_text' fn_name from dual where lower('&report_type') = 'text';
select 'awr_report_html' fn_name from dual where lower('&report_type') <> 'text';

column lnsz new_value lnsz noprint;
select '80' lnsz from dual where lower('&report_type') = 'text';
select '8000' lnsz from dual where lower('&report_type') <> 'text';

set linesize &lnsz;
set termout off;
variable dbid       number;
variable inst_num   number;
variable bid        number;
variable eid        number;
variable rpt_options number;
begin
null;
end;
/
begin
  :rpt_options := 0;
  :dbid      :=  &dbid;
  :inst_num  :=  &inst_num;
  :bid       :=  &begin_snap;
  :eid       :=  &end_snap;
end;
/

spool &report_name;

-- call the table function to generate the report
select output from table(dbms_workload_repository.&fn_name( :dbid,
                                                            :inst_num,
                                                            :bid, :eid,
                                                            :rpt_options ));

spool off;

prompt Report written to &report_name.

set termout off;
clear columns sql;
ttitle off;
btitle off;
repfooter off;
set linesize 78 termout on feedback 6 heading on;
-- Undefine report name (created in awrinput.sql)
undefine report_name

undefine report_type
undefine ext
undefine fn_name
undefine lnsz

undefine NO_OPTIONS
undefine ENABLE_ADDM

undefine top_n_events
undefine num_days
undefine top_n_sql
undefine top_pct_sql
undefine sh_mem_threshold
undefine top_n_segstat

whenever sqlerror continue;
--
--  End of script file;
