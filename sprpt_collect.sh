#!/bin/ksh
#
# sprpt_collect.sh
#
#
#
# =============================================================================

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

if [ -f ${THISDIR}/dprpt_common/sh ];then
    . ${THISDIR}/dprpt_common/sh
fi

GET_SNAPSHOT_QUERY=sprpt_get_snapshot_range.sql
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

TMPFILE=${CFGDIR}/dbrpt_collect_temp_%%.txt

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
    echo "." >xx.log
    if [ ! -z "${dbname}" ];then
        echo "Processing $dbname in $instance"

         details=$(get_db_details $DBDEF $instance)
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
set -x
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
