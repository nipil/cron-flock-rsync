#! /usr/bin/env bash

##############################################################################
# util functions
err() { >&2 echo $@; }
log() { echo $@ >> ${LOG}; }
cleanup() { rm -f ${TMP1} ${TMP2}; }

##############################################################################
# test parameters
if [[ -z $1 || -z $2 || -z $3 ]]
then
	err "Usage: $0 SYNC_ID RSYNC_SRC RSYNC_DST [NOTIFY]" 1>&2
	exit 1
fi

##############################################################################
# set variables
RSYNC_ID=${1}
RSYNC_SRC=${2}
RSYNC_DST=${3}
NOTIFY=${4:-toto}
LOG=${0}.${1}.log
LOCK=${0}.${1}.lock
LAST=${0}.${1}.last
FLOCK_ERR=100
TIMESTAMP_START=$(date +'%F %T')

##############################################################################
# create temporary files
TMP1=$(mktemp -p /tmp "tmp_$1.XXXXXXXXXX")
RES=${?}
if [ ${RES} -ne 0 ]
then
	err "cannot create temporary file"
	exit 1
fi
TMP2=$(mktemp -p /tmp "tmp_$1.XXXXXXXXXX")
RES=${?}
if [ ${RES} -ne 0 ]
then
	err "cannot create temporary file"
	exit 1
fi

##############################################################################
# do sync
flock -x -n -E ${FLOCK_ERR} ${LOCK} rsync -a -v ${RSYNC_SRC} ${RSYNC_DST} 2>${TMP2} 1>${TMP1}
RES=${?}
TIMESTAMP_END=$(date +'%F %T')

##############################################################################
# manage flock errors
if [ ${RES} -eq ${FLOCK_ERR} ]
then
	echo "${TIMESTAMP_END}: already running" > ${LAST}
	cleanup
	exit ${FLOCK_ERR}
fi

##############################################################################
# manage rsync errors
if [ ${RES} -ne 0 ]
then
	MSG="[ERROR] rsync failed with return code ${RES}"

	# last
	echo "${TIMESTAMP_END}: ${MSG}" > ${LAST}

	# log
	log "========== ${TIMESTAMP_START} to ${TIMESTAMP_END} =========="
	log ${MSG}
	log "STDOUT dump:"
	cat ${TMP1} >> ${LOG}
	log "STDERR dump:"
	cat ${TMP2} >> ${LOG}

	# cron output
	err ${MSG}

	cleanup
	exit ${RES}
fi

##############################################################################
# check activity
ACTIVITY=$(cat ${TMP1} | head -n -3 | tail -n +2 | grep -v '^\./$' | wc -l)
echo "${TIMESTAMP_END}: activity=${ACTIVITY}" > ${LAST}

##############################################################################
# log details
if [ ${ACTIVITY} -ne 0 ]
then
	log "========== ${TIMESTAMP_START} to ${TIMESTAMP_END} =========="
	log "[SUCCESS] ${ACTIVITY} items sync'ed"
	log "STDOUT dump:"
	cat ${TMP1} >> ${LOG}
fi

##############################################################################
# cleanup temporary file
cleanup

##############################################################################
# exit with stored status code
exit 0

