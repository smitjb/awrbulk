#/bin/ksh
#
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

bsnap=$1
esnap=$2
P_DBID=$3
P_INSTANCE=$4
P_DBNAME=$5
CONNECT_STRING=$6

if [ -z "${CONNECT_STRING}" ];then
    CONNECT_STRING="/ as sysdba"
fi

function getDatabaseDetails {
#set -x
sqlplus -s  ${CONNECT_STRING} <<EOSQL
set termout on heading off feedback off timing off
select instance_number, instance_name,name ,dbid from
v\$database,v\$instance;
EOSQL

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
set trimspool on trimout on
set feedback off
set verify off
whenever sqlerror exit 1
declare
    t_cnt number;
begin
    select count(*)
    into t_cnt
    from  perfstat.stats\$snapshot
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



define  db_name      = '$DBNAME';
set linesize 8000;
set termout off
@@../../bpspreport $bsnap1 $csnap1
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
report $bsnap $esnap
let osnap=$bsnap
while  [[ $osnap -lt $esnap ]]
do
    csnap=$osnap+1
    report $osnap $csnap
    osnap=$csnap
done
exit
