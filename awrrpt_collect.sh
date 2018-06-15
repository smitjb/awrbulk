#!/bin/ksh
#
# awrrpt_collect.sh
#
#
#
# =============================================================================

function look_up_password {
    UNAME=$1
    SID=$2
    ssh ramxtxus370.am.ist.bp.com "grep -i :${UNAME}: /var/opt/oracle/pwfile | nawk -F: -v SAD=$SID '\$2==SAD  { print \$4 }';"

}
function get_job_details {
    DBDEF=$1
        
    grep "^DEF:${DBDEF}:" ${PROPSFILE}  | sed 's/:/ /g' 
    
}

function get_db_details {
    DB=$1
    con=$(get_con $DB)
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

grep "^CON:${DB}" ${PROPSFILE}  | sed 's/:/ /g' | while read rectype dbname uname pwd
do
  if [ -z "${pwd}" -o "${pwd}" = "LOOKUP" ];then
      pwd=$(look_up_password $uname $DB)
  fi      
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
@${SQLDIR}/awrrpt_get_snapshot_range ${1} ${2}
EOSQL
}

#
# MAIN
#
THISDIR=$(dirname $0)

if [ -z "${THISDIR}" -o "." == "${THISDIR}" ]; then
    THISDIR=$( dirname $( which $0 ))
fi
if [ -z "${THISDIR}" -o "." == "${THISDIR}" ];then
    THISDIR=$(pwd)
fi
REPORTDIR=${THISDIR}/REPORTS


# Set various directories according to whether there is a full
# installation or a single directory installation.
#
if [ -d ${THISDIR}/../SHELL ];then
    BINDIR=${THISDIR}/../SHELL
    SQLDIR=${THISDIR}/../SQL
    CFGDIR=${THISDIR}/../etc
else
    BINDIR=${THISDIR}
    SQLDIR=${THISDIR}
    CFGDIR=${THISDIR}
fi

TMPFILE=${CFGDIR}/awrrpt_collect_temp_%%.txt

if [ -f ${CFGDIR}/awrrpt.env ];then
    .  ${CFGDIR}/awrrpt.env

    #
    # Depends on instant client or full oracle install
    #
    if [ -x $ORACLE_HOME/bin/sqlplus ];then
        PATH=$ORACLE_HOME/bin:$PATH
    else
        PATH=${ORACLE_HOME}:$PATH
    fi
    LD_LIBRARY_PATH=${ORACLE_LIB}:$LD_LIBRARY_PATH
    export PATH LD_LIBRARY_PATH
else
    echo "Unable to open environment file"
    exit 1
fi

PROPSFILE=${1}
if [ -z "${PROPSFILE}" ];then
    PROPSFILE=${DEFAULT_PROPERTIES}
else
	shift
fi
PROPSFILE=${CFGDIR}/${PROPSFILE}
if [ ! -f ${PROPSFILE} ];then
    echo "Properties file [$PROPSFILE] does not exist, aborting"
    exit 1
fi
#
# backup the props file
#
cp $PROPSFILE $PROPSFILE.pre_backup
diff $PROPSFILE $PROPSFILE.pre_backup >/dev/null 
if [ $? -ne 0 ];then
	echo "Diff error backing up $PROPSFILE. Possible space issue"
        exit 1
fi

if [ ! -z ${SQLBULK_DEBUG} ];then
    SQLDEBUGSILENT=""
else
    SQLDEBUGSILENT="-s"

fi
export SQLDEBUGSILENT
cd ${SQLDIR}


DBLIST=$*
if [ -z "${DBLIST}" ];then
  DBLIST=$( grep "^DEF:" ${PROPSFILE} | awk -F: '{ print $2 }' )
fi
echo "Looping through databases [${DBLIST}] "
for DBDEF in ${DBLIST}
do
     jobdetails=$( get_job_details ${DBDEF})
     if [ -z ${jobdetails} ];then
        echo "Failed to get job details" 
     else
        set ${jobdetails}
     fi

     set ${jobdetails}
     rectype=$1; dbname=$2; instance=$3; lastsnap=$4; lasttime=$5;
    unset LOCAL
    unset CRED
    if [ ! -d ${REPORTDIR}/${instance} ];then
	mkdir ${REPORTDIR}/${instance}
    fi
    cd ${REPORTDIR}/${instance}
    if [ ! -z "${dbname}" ];then
        echo "Processing $dbname in $instance"

         details=$(get_db_details $DBDEF)
         if [ -z ${details} ];then
             echo "Failed to get db details"
          else
             echo "Got details"
             set $details
         fi

         set $details
         LOCAL=$3:$4/$5
         UNAME=$1
         PW=$2 
        ORACLE_SID=$instance
        #LOCAL=$(get_url ${dbname} )
        #CRED=$(get_con ${dbname} )
        CRED=${UNAME}/${PW}
        LDBNAME=$(echo ${dbname} | tr '[A-Z]' '[a-z]' )
        export UNAME PW LOCAL
        if [ ! -z ${SQLBULK_DEBUG} ];then
            echo "[ ${UNAME} | ${PW} | ${LOCAL} ]"
            test_connection ${UNAME} ${PW}  ${LOCAL}
        fi
        range=$(get_snapshot_range $dbname $lastsnap) 
        set $range
        bsnap=$1;esnap=$2;dbid=$3; sid=$4; db=$5; instnum=$6; ver=$7; host=$8;
        if [ ! -z ${bsnap} ];then
            tstamp=$( date +%Y%m%d%H%M%S)
            if [ ! -z ${SQLBULK_DEBUG} ];then
                echo "[$bsnap, $esnap, $dbid, $sid, $db,$instnum,$ver, $host ]"
            fi
            echo "${BINDIR}/awrrpt_bulk.sh $bsnap $esnap $dbid $sid $db ${UNAME}@${LOCAL}"
            ${BINDIR}/awrrpt_bulk.sh -b$bsnap -e$esnap -i$dbid -s$sid -d$db -c${UNAME}/${PW}@${LOCAL} -I
            if [ $? -ne 0 ];then
                # report error
                echo "Error"
            else
                if [ "${RECYCLE_SNAPSHOTS}" = "N" ];then
                    # update last and process
                    update_job_details  $dbname $instance $esnap $tstamp
                fi
                zipfile=$(make_zip_file ${dbname} ${tstamp} ${instance} ${LDBNAME})
                #zip -m awr_reports_${dbname}_${tstamp}.zip awr_report_${instance}*.html awr_report_${LDBNAME}*.html
                if [ ! -d ${REPORT_LOCATION}/${dbname} ];then
                    mkdir ${REPORT_LOCATION}/${dbname}
                fi
                mv ${zipfile} ${REPORT_LOCATION}/${dbname}
                #mv  awr_reports_${dbname}_${tstamp}.zip  ${REPORT_LOCATION}/${dbname}
            fi

        fi
    fi
cd ${THISDIR}
done
