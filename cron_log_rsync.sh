#! /usr/bin/env bash

##############################################################################
# util functions
err() { >&2 echo $@; }
log() { echo $@ >> ${LOG}; }
cleanup() { rm -f ${TMP1} ${TMP2}; }
fail() {
	cleanup
	# display message if provided
	[[ -n ${1} ]] && err ${1};
	# exit with provided status code, if any
	[[ -n ${2} ]] && exit ${2} || exit 1;
}

##############################################################################
# test parameters
[[ -n $1 && -n $2 && -n $3 ]] || fail "Usage: $0 SYNC_ID RSYNC_SRC RSYNC_DST"

##############################################################################
# set variables
RSYNC_ID=${1}
RSYNC_SRC=${2}
RSYNC_DST=${3}
LOG=${0}.${1}.log
LOCK=${0}.${1}.lock
LAST=${0}.${1}.last
ACT=${0}.${1}.list
FLOCK_ERR=100

##############################################################################
# create temporary files
TMP1=$(mktemp -p /tmp "tmp_$1.XXXXXXXXXX")
[[ ${?} -eq 0 ]] || fail "cannot create temporary file"
TMP2=$(mktemp -p /tmp "tmp_$1.XXXXXXXXXX")
[[ ${?} -eq 0 ]] || fail "cannot create temporary file"

##############################################################################
# do sync
TIMESTAMP_START=$(date +'%F %T')
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

	# cron output and exit
	fail ${MSG} ${RES}
fi

##############################################################################
# check activity

cat ${TMP1} | head -n -3 | tail -n +2 | grep -v '^\./$' > ${ACT}
[[ ${?} -eq 0 ]] || fail "cannot create activity file"
ACTIVITY=$(cat ${ACT} | wc -l)
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

