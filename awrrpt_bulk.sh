#/bin/ksh
#
# Parameters
# -b    begin snap
# -e    end snap
# -i    dbid
# -s    sid
# -d    dbname
# -c    credentials
# -S    summary (first and last)
# -I    interval every pair inbetween.
# $bsnap $esnap $dbid $sid $db ${CRED}@${LOCAL}
#      define  inst_num     = 1;
#      define  num_days     = 3;
#      define  inst_name    = 'Instance';
#      define  db_name      = 'Database';
#      define  dbid         = 4;
#      define  begin_snap   = 10;
#      define  end_snap     = 11;
#      define  report_type  = 'text';
#      define  report_name  = /tmp/swrf_report_10_11.txt
#      @@?/rdbms/admin/awrrpti

typeset -i bsnap
typeset -i esnap
typeset -i osnap
typeset -i csnap


   while getopts :b:e:i:s:d:c:SI OPTION "$@"
   do
      case $OPTION in
         b) bsnap=${OPTARG} ;;
         e) esnap=${OPTARG} ;;
         i) P_DBID=${OPTARG} ;;
         s) P_INSTANCE=${OPTARG} ;;
         d) P_DBNAME=${OPTARG} ;;
         c) CONNECT_STRING=${OPTARG} ;;
         S) SUMMARY="Y" ;;
         I) INTERVAL="Y" ;;
      esac
   done

if [ -z "${CONNECT_STRING}" ];then
    CONNECT_STRING="/ as sysdba"
fi

function getDatabaseDetails {
#set -x
if [ -z "${1}" ];then
sqlplus -s  ${CONNECT_STRING} <<EOSQL
set termout on heading off feedback off timing off
select instance_number, instance_name,name ,dbid from
v\$database,v\$instance;
EOSQL
else

sqlplus -s ${CONNECT_STRING} <<EOSQL
set termout on heading off feedback off timing off
select distinct
        wr.instance_number instt_num
      , wr.instance_name   instt_name
      , wr.db_name         dbb_name
      , wr.dbid   dbbid
      from dba_hist_database_instance wr
  where WR.dbid=  ${1}
  AND WR.INSTANCE_NAME='${2}'
  and WR.DB_NAME='${3}';
EOSQL
fi
}

#
# MAIN
#
#set -x
unset SQLPATH
if  [ -z "${P_DBID}" ];then
    DBDETAILS=$(getDatabaseDetails)
else
    DBDETAILS=$(getDatabaseDetails ${P_DBID} ${P_INSTANCE} ${P_DBNAME})
fi

echo "[$DBDETAILS]"
INSTNUM=$( echo $DBDETAILS|awk '{ print $1 }' )
INSTANCE=$( echo $DBDETAILS|awk '{ print $2 }' )
DBNAME=$( echo $DBDETAILS|awk '{ print $3 }' )
DBID=$( echo $DBDETAILS|awk '{ print $4 }' )


function report {
    bsnap1=${1}
    csnap1=${2}


SQLPLUSDBGOPT="-s"
echo "report $bsnap1 $csnap1"
sqlplus ${SQLPLUSDBGOPT} ${CONNECT_STRING} <<-EOSQL
set termout off
set heading off
set feedback off
set trimspool on trimout on
set verify off
whenever sqlerror exit 1
declare
    t_cnt number;
begin
    select count(*)
    into t_cnt
    from  dba_hist_snapshot
    where snap_id in (${bsnap1},${csnap1});
    if t_cnt < 2 then
        raise no_data_found;
    end if;
exception
    when others then
        dbms_output.put_line(sqlerrm);
        raise;
end;
/
conn ${CONNECT_STRING}

variable rpt_options number;
variable dbid       number;
variable inst_num   number;
variable bid        number;
variable eid        number;

-- option settings
define NO_OPTIONS   = 0;
define ENABLE_ADDM  = 8;

-- set the report_options. To see the ADDM sections,
-- set the rpt_options to the ENABLE_ADDM constant.
begin
  :dbid      :=  $DBID;
  :inst_num  :=  $INSTNUM;
  :rpt_options := &NO_OPTIONS;
  :bid       :=  $bsnap1;
  :eid       :=  $csnap1;
end;
/



define  db_name      = '$DBNAME';
define  report_name  = awr_report_${INSTANCE}_${TSTAMP}_${bsnap1}_${csnap1}.html
set linesize 8000;
set termout off
spool &report_name;
@@${THISDIR}/do_report
spool off
exit
EOSQL

if [ $? -ne 0 ];then
    echo "report failed"
fi
}

TSTAMP=$(date +%y%m%d_%H%M%S)
export TSTAMP
if [ ! -z ${SQLBULK_DEBUG} ];then
    echo "[$TSTAMP]"
fi
echo "range $bsnap $esnap"
if [ "${SUMMARY}" = "Y" ];then
        report $bsnap $esnap
fi

if [ "${INTERVAL}" = "Y" ];then
    let osnap=$bsnap
    while  [[ $osnap -lt $esnap ]]
    do
        csnap=$osnap+1
        report $osnap $csnap
        osnap=$csnap
    done
fi
exit
