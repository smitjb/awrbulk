#!/bin/ksh
#
# sprpt_collect.sh
#
#
#
# =============================================================================

function look_up_password {
    UNAME=$1
    SID=$2
      echo "look_up_password[$SID][$UNAME][$pwd]" >>xx.log
    ssh ramxtxus370.am.ist.bp.com "grep -i :${UNAME}: /var/opt/oracle/pwfile | nawk -F: -v SAD=$SID '\$2==SAD  { print \$4 }';"

}
function get_job_details {
    DBDEF=$1

    grep "^DEF:${DBDEF}:" ${PROPSFILE}  | sed 's/:/ /g'

}

function get_db_details {
set -x
    DB=$1
    INST=$2
    con=$(get_con $DB $INST)
    echo "get_db_details[$DB][$con]" >>xx.log

    if [ -z ${con} ];then
        echo "FATAL:get_con failed"
    else
        set $con
    fi

    uname=$1
    pwd=$2
    url=$(get_url $DB)
    if [ -z ${url} ];then
        echo "FATAL:get_url failed"
    else
        set $url
    fi

    set $url
    host=$1
    port=$2
    service=$3

    echo "$uname $pwd $host $port $service"
set +x
}

function update_job_details {
    dbname=$1
    instance=$2
    esnap=$3
    tstamp=$4

    # lock file
    # update last and process
    echo "No error"
    echo "Updating [$dbname] with [$esnap]"
    sed  -e " /^DEF:$dbname/ d" -e "/^$/ d" <${PROPSFILE}  >$TMPFILE
    cat <<-EOCAT >>${TMPFILE}
DEF:$dbname:$instance:$esnap:$tstamp
EOCAT
    mv ${TMPFILE} ${PROPSFILE}
   # unlock file
}

function make_zip_file {
        dbname=$1
        tstamp=$2
        instance=$3
        LDBNAME=$4
        zip_file_name=awr_reports_${dbname}_${tstamp}.zip
        zip -m ${zip_file_name} awr_report_${instance}*.html awr_report_${LDBNAME}*.html >/dev/null

        echo ${zip_file_name}

}


function get_con {
  DB=${1}
  INST=$2
grep "^CON:${DB}:" ${PROPSFILE}  |  sed 's/:/ /g' | while read rectype dbname uname pwd
do
  if [ -z "${pwd}" -o "${pwd}" = "LOOKUP" ];then
      echo "get_con 1[$DB][$uname][$pwd]" >>xx.log
      pwd=$(look_up_password $uname $INST)
  fi
      echo "get_con 2[$DB][$uname][$pwd]" >>xx.log
  echo "${uname} ${pwd}"
done

}


function get_url {
  DB=${1}

grep "^URL:${DB}" ${PROPSFILE}  | sed 's/:/ /g' | while read rectype dbname host port service
do
  if [ -z ${port} ];then
      echo ${host}    # tns alias only
    else
      echo "${host} ${port} ${service}"  # full econnect syntax.
  fi
done

}

function test_connection {
    U=$1
    P=$2
    L=$3
 set -x
 echo "[${TNS_ADMIN}]"
 cat ${TNS_ADMIN}/sqlnet.ora
 sqlplus -L ${U}/${P}@${L} <<EOSQL
exit 0
EOSQL
if [ $? -ne 0 ];then
        echo "Connection failed"
        exit 1
fi

 set +x
}


function get_snapshot_range {
    sqlplus  ${SQLDEBUGSILENT} ${CRED}@${LOCAL} <<EOSQL
set termout on heading off feedback off timing off  verify off
set linesize 200
set trimout on
@${SQLDIR}/${SNAPSHOT_RANGE_QUERY} ${1} ${2}
EOSQL
}

