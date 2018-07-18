#!/bin/ksh
#
# sprpt_collect.sh
#
#
#
# =============================================================================
function get_password {
  db=${1}
  uname=${2}

#echo "Fetching ${uname} password for ${db}"
ssh -l oracle ramxtxus370.am.ist.bp.com   grep -i :${db}: /var/opt/oracle/pwfile | grep -i ${uname}| awk -F: ' { print $4 } '



}

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

TMPFILE=${CFGDIR}/sprpt_collect_temp_%%.txt

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

function get_con {
  DB=${1}

grep "^CON:${DB}" ${PROPSFILE}  | sed 's/:/ /g' | while read rectype dbname uname pwd
do
   if [ -z ${uname} ];then
        return 1
   fi
   if [ -z ${pwd} ];then
        pwd=$(get_password $DB ${uname})
   fi
   if [ -z ${pwd} ];then
        return 1;
   fi
  echo "${uname}/${pwd}"
  return 0;
done


}
function get_url {
  DB=${1}

grep "^URL:${DB}" ${PROPSFILE}  | sed 's/:/ /g' | while read rectype dbname host port service
do
  if [ -z ${port} ];then
      echo ${host}    # tns alias only
    else
      echo "${host}:${port}/${service}"  # full econnect syntax.
  fi
done

}

function test_connection {
 set -x
 echo "[${TNS_ADMIN}]"
 cat ${TNS_ADMIN}/sqlnet.ora
 sqlplus -L ${CRED}@${LOCAL} <<EOSQL
exit 0
EOSQL
if [ $? -ne 0 ];then
        echo "Connection failed"
        exit 1
fi

 set +x
}

    
function get_snapshot_range {
    #echo sqlplus  ${SQLDEBUGSILENT} ${CRED}@${LOCAL} 
    sqlplus  ${SQLDEBUGSILENT} ${CRED}@${LOCAL} <<EOSQL
set termout on heading off feedback off timing off  verify off
set linesize 200
set trimout on
@${SQLDIR}/sprpt_get_snapshot_range ${1} ${2}
EOSQL
}

DBLIST=$*
if [ -z "${DBLIST}" ];then
  DBLIST=$( grep "^DEF:" ${PROPSFILE} | awk -F: '{ print $2 }' )
fi
echo "Looping through databases [${DBLIST}] "
for DBDEF in ${DBLIST}
do
grep "^DEF:${DBDEF}" ${PROPSFILE}  | sed 's/:/ /g' | while read rectype dbname instance lastsnap lasttime
do
    unset LOCAL
    unset CRED
    if [ ! -d ${REPORTDIR}/${instance} ];then
	mkdir ${REPORTDIR}/${instance}
    fi
    cd ${REPORTDIR}/${instance}
    if [ ! -z "${dbname}" ];then
        echo "Processing $dbname in $instance"
        #set -x
        ORACLE_SID=$instance
        LOCAL=$(get_url ${dbname} )
        CRED=$(get_con ${dbname} )
        LDBNAME=$(echo ${dbname} | tr '[A-Z]' '[a-z]' )
        export CRED LOCAL
        if [ ! -z ${SQLBULK_DEBUG} ];then
            echo "[ ${CRED} | ${LOCAL} ]"
            test_connection
        fi
        get_snapshot_range $dbname $lastsnap | while read bsnap esnap dbid sid db instnum ver host
        do
            if [ ! -z ${bsnap} ];then
                tstamp=$( date +%Y%m%d%H%M%S)
                if [ ! -z ${SQLBULK_DEBUG} ];then
                    echo "[$bsnap, $esnap, $dbid, $sid, $db,$instnum,$ver, $host ]"
                fi
                echo "${BINDIR}/sprpt_bulk.sh $bsnap $esnap $dbid $sid $db ${CRED}@${LOCAL}"
                ${BINDIR}/sprpt_bulk.sh $bsnap $esnap $dbid $sid $db ${CRED}@${LOCAL}
                if [ $? -ne 0 ];then
                    # report error
                    echo "Error"
                else
                    if [ "${RECYCLE_SNAPSHOTS}" = "N" ];then
                    # update last and process
                    echo "No error"
                    sed  -e " /^DEF:$dbname/ d" -e "/^$/ d" <${PROPSFILE}  >$TMPFILE
                    cat <<-EOCAT >>${TMPFILE}
DEF:$dbname:$instance:$esnap:$tstamp
EOCAT
                    mv ${TMPFILE} ${PROPSFILE}
                    fi
                    zip -m statspack_reports_${dbname}_${tstamp}.zip sp_${instance}*.lst sp_${LDBNAME}*.lst
                    if [ ! -d ${REPORT_LOCATION}/${dbname} ];then
                        mkdir ${REPORT_LOCATION}/${dbname}
                    fi
                    mv  statspack_reports_${dbname}_${tstamp}.zip  ${REPORT_LOCATION}/${dbname}
                fi
            
            fi
            
        done
    fi
cd ${THISDIR}
done
done
