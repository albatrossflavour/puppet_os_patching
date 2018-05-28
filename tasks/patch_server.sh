#!/bin/sh
#
# Simple patching for RedHat only.
# Patch, check for basic errors and reboot.
#

# Variables to be updated based on run.
PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin
export PATH
DATE=`date +"%Y%m%d"`
REBOOT=0
SECONLY=""

case $PT_reboot in
  true|True)   REBOOT=1 ;;
  false|False) REBOOT=0 ;;
  *)           REBOOT=0 ;;
esac

# The security only tagging works with RHEL with an official
# feed from Redhat.  CentOS doesn't seem to have the same metadata
case $PT_security_only in
  true|True)   SECONLY="--security" ;;
  false|False) SECONLY="" ;;
  *)           SECONLY="" ;;
esac

# What is this event we are working on?
EVENT="PATCHING_${DATE}"

# Constants - not to be modified
LOCKFILE=/tmp/.patch_run_${DATE}.lockfile
LOGFILE=/var/log/os_patching.${DATE}
FAILMSG=
FACTDIR=/opt/puppetlabs/facter/facts.d/
FACTFILE=${FACTDIR}/PATCHSTATE.yaml
FACTER=/usr/local/bin/facter
if [ ! -x ${FACTER} ]; then
  echo "ERROR: This Cannot find facter command"
  exit 1
fi
HOSTRELEASE=`${FACTER} os.release.full`
if [ $? -ne 0 ]; then
  echo "ERROR: Facter had an error - aborting"
  exit 1
fi
HOSTMAJOR=`echo ${HOSTRELEASE} | awk -F. '{print $1}'`

# Patch states 0-2 are used in the pre and post scripts
PATCHSTATE0="0-patchscriptstart"
PATCHSTATE1="1-precheckscomplete"
PATCHSTATE3="3-yumdryrun"
PATCHSTATE4="4-yumrun"
PATCHSTATE5="5-yumdryrun"
PATCHSTATE6="6-rebootpending"
PATCHSTATE7="7-rebootaborted"
PATCHSTATE8="8-rebootstarted"
PATCHSTATE9="9-rebootcompleted"
PATCHSTATE10="10-noactionrequired"

# Log a message
# If our type arg is non-zero, clean up and exit with this code
send_message()
{
  TYPE=$1
  MESSAGE="$2"
  LOGGER=/bin/logger
  if [ ! -x ${LOGGER} ]; then
    echo "`date +'%Y%m%d%H%M.%SS'`: ${EVENT} ${MESSAGE}" >> /dev/console
  else
    case ${TYPE} in
      0) ${LOGGER} -t ${EVENT} -p local0.notice "${MESSAGE}" ;;
      *) ${LOGGER} -t ${EVENT} -p local0.error "${MESSAGE}" ;;
    esac
  fi
  if [ ${TYPE} -ne 0 ]; then
    # Force a puppet run to get facts into DB
    # For successful patching, puppet runs after reboot
    if [ -x /opt/puppetlabs/puppet/bin/puppet ]; then
      PUPPET=/opt/puppetlabs/puppet/bin/puppet
    elif [ -x /usr/local/bin/puppet ]; then
      PUPPET=/usr/local/bin/puppet
    else
      PUPPET=
    fi
    if [ ! -z "${PUPPET}" ]; then
      ( cd /tmp ; nohup ${PUPPET} agent -t >/dev/null ) &
    fi
    JSON=`cat << EOF
{
  "_error": {
    "kind": "yum_error",
    "msg": ${MESSAGE},
    "details": {},
  }
}
EOF
`
    echo ${JSON}
    exit ${TYPE}
  fi
}

#
# Clean up after ourselves
clean_up()
{

  if [ "${HOSTMAJOR}" = "7" ]; then
    echo '@reboot root /etc/rc3.d/S90postpatchfacts' > /etc/cron.d/${EVENT}
  fi

  # Write out an RC script that runs after a reboot
  # Puppet runs at S98 ..
echo "#!/bin/sh
DATE=\`date +\"%Y%m%d%H%M.%SS\"\`
echo \"PATCHEVENT : \\\"${EVENT}\\\"\" > ${FACTFILE}
echo \"PATCHSTATE : \\\"${1}\\\"\" >> ${FACTFILE}
echo \"PATCHEVENTTIME : \\\"\${DATE}\\\"\" >> ${FACTFILE}
/bin/rm -f /etc/rc3.d/S90postpatchfacts /etc/cron.d/${EVENT}
" > /etc/rc3.d/S90postpatchfacts
  chmod 755 /etc/rc3.d/S90postpatchfacts
  if [ "$2" == 'now' ]; then
    /etc/rc3.d/S90postpatchfacts
  fi
}


#
# Write out fact data to show where we are in the sequence
# See constants above for messages
write_patch_fact()
{
  THEFACT=$1
  if [ -z "${THEFACT}" ]; then
    send_message 1 "ERROR: Must supply a fact to write_patch_fact - aborting"
  fi
  if [ ! -d ${FACTDIR} ]; then
    mkdir -p ${FACTDIR}
    if [ $? -ne 0 ]; then
      send_message 1 "ERROR: Fact directory create failed - aborting"
    fi
  fi
  echo "PATCHSTATE : \"${THEFACT}\"" > ${FACTFILE}
  if [ $? -ne 0 ]; then
    send_message 1 "ERROR: Fact file write failed - aborting"
  fi
  if [ ! -z "${FAILMSG}" ]; then
    echo "PATCHMESSAGE : \"${FAILMSG}\"" > ${FACTFILE}
    if [ $? -ne 0 ]; then
      send_message 1 "ERROR: Fact file write failed - aborting"
    fi
  fi
  echo "PATCHEVENTTIME : \"`date +'%Y%m%d%H%M.%SS'`\"" >> ${FACTFILE}
  if [ $? -ne 0 ]; then
    send_message 1 "ERROR: Fact file write failed - aborting"
  fi
  echo "PATCHEVENT : \"${EVENT}\"" >> ${FACTFILE}
  if [ $? -ne 0 ]; then
    send_message 1 "ERROR: Fact file write failed - aborting"
  fi
}


# Set fact - we are go
send_message 0 "NOTICE: Patch run proper continuing"
write_patch_fact "${PATCHSTATE3}"

# Set fact - yum first check as dry run
send_message 0 "NOTICE: Patch initial dry run starting"

# Start the dry run
yum clean all 2>/dev/null 1>/dev/null
yum $SECONLY check-update 2>/dev/null 1>/dev/null
case $? in
  0)
    FAILMSG="No patches to apply"
    write_patch_fact "${PATCHSTATE3}-noop"
    send_message 0 "NOTICE: Yum dry run shows no patching work to do - exiting"
    FQDN=`${FACTER} fqdn`
    JSONDATE=`date`
    JSON=`cat <<EOF
{
  "fqdn": "$FQDN",
  "return-code": "success",
  "date": "$JSONDATE",
  "message": "yum dry run shows no patching work to do",
  "logfile": "$LOGFILE",
  "reboot": "$PT_reboot",
  "securityonly": "$PT_security_only",
}
EOF
`

    echo $JSON
    clean_up ${PATCHSTATE10} now
    exit 0
    ;;
  100)
    send_message 0 "NOTICE: Yum dry run shows patches to be applied"
    FAILMSG="No patches to apply"
    write_patch_fact "${PATCHSTATE3}-success"
    ;;
  *)
    FAILMSG="Yum unknown exit code"
    write_patch_fact "${PATCHSTATE3}-fail"
    send_message 3 "ERROR: Yum dry run failed - unknown exit code"
    ;;
esac

# Set fact - yum has finished with an exit code
send_message 0 "NOTICE: Patch package installation starting"

# Actually do the patching!
yum $SECONLY upgrade -y >> ${LOGFILE} 2>&1
YUMEXIT=$?

# Yum said yes, but we simply do not trust it in low space situations ...
# Do we have a fact warning?
${FACTER} -p patchdata.spaceblocker.boot_less_100mb | grep no >/dev/null
if [ $? -eq 0 ]; then
  FAILMSG="Not enough space in /boot"
  write_patch_fact "${PATCHSTATE4}-fail-bootspace"
  send_message 3 "ERROR: Yum run failed - not enough space in /boot to install new kernel"
fi

egrep "to work around the problem" ${LOGFILE} >/dev/null
if [ $? -eq 0 ]; then
  FAILMSG="Not Package dependency failure"
  write_patch_fact "${PATCHSTATE4}-fail-dependency"
  send_message 3 "ERROR: Yum run failed - package dependency failure"
fi
egrep "gzip.*No space left on device" ${LOGFILE} >/dev/null
if [ $? -eq 0 ]; then
  FAILMSG="Space error causing corrupt kernel"
  write_patch_fact "${PATCHSTATE4}-fail-corruptkernel"
  send_message 3 "ERROR: Yum run failed - it said it worked but lies - out of space to build kernel"
fi

# If we haven't found any known errors above, then trust the yum exit code
case ${YUMEXIT} in
  0)
    write_patch_fact "${PATCHSTATE4}-success"
    send_message 0 "NOTICE: Yum run was successful"
    ;;
  *)
    FAILMSG="Yum unknown error code"
    write_patch_fact "${PATCHSTATE4}-fail"
    send_message 3 "ERROR: Yum run failed - unknown exit code"
    ;;
esac

# Set fact - yum second check as dry run
send_message 0 "NOTICE: Patch second dry run starting"
yum $SECONLY check-update 2>/dev/null 1>/dev/null
case $? in
  0)
    write_patch_fact "${PATCHSTATE5}-success"
    send_message 0 "NOTICE: Yum dry run shows no patching work to do - ready for reboot"
    ;;
  100)
    FAILMSG="Yum shows more patches to apply after first pass"
    write_patch_fact "${PATCHSTATE5}-fail"
    send_message 3 "ERROR: Yum dry run shows patches to be applied - error"
    ;;
  *)
    FAILMSG="Yum unknown error code"
    write_patch_fact "${PATCHSTATE5}-fail"
    send_message 3 "ERROR: Yum dry run failed - unknown exit code"
    ;;
esac

yum clean all 2>/dev/null 1>/dev/null
write_patch_fact "${PATCHSTATE6}-success"

# Verification checks - external - check that we got the packages we expected.
# This is highly customised for each patch run and must cover the list
# of supported OS versions from the pre-check script.
# We expect the verification script to return 0 on success and 1 on failed to verify.

FQDN=`${FACTER} fqdn`
JSONDATE=`date`
JOB=`yum history | egrep "^[[:space:]]" | awk '{print $1}' | head -1`
RETURN=`yum history info $JOB | awk '$1 == "Return-Code" {print $3}'`
PACKAGES=`yum history info $JOB | egrep "Updated" | awk '{print t "\"" $2 "\""} { t=", "}'`

JSON=`cat <<EOF
{
  "fqdn": "$FQDN",
  "return-code": "$RETURN",
  "date": "$JSONDATE",
  "packagesupdated": [
    $PACKAGES
  ]
  "logfile": "$LOGFILE",
  "reboot": "$PT_reboot",
  "securityonly": "$PT_security_only",
  "message": "Patching complete",
}
EOF
`

echo $JSON

write_patch_fact "${PATCHSTATE8}"
send_message 0 "NOTICE: Verify of required packages succeeded - rebooting"
clean_up ${PATCHSTATE9}

if [ "$REBOOT" -gt 0 ]
then
  # Reboot option set to true, reboot the system
  /sbin/shutdown -r now
fi

exit 0
