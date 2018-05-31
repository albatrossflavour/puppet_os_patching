#!/bin/sh

PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin
FQDN=$(facter fqdn)
FAMILY=$(facter osfamily)
STARTDATE=$(date)
LOGGER='/usr/bin/logger -p info -t os_patching'

${LOGGER} "Starting patch run task"

# Default to not rebooting.  PT_reboot comes in from puppet tasks
case ${PT_reboot} in
  true)  REBOOT=1 ;;
  *)     REBOOT=0 ;;
esac

${LOGGER} "patch task set post run reboot to $PT_reboot"

case $FAMILY in
  RedHat)
    # The security only tagging works with RHEL with an official
    # feed from Redhat.  CentOS doesn't seem to have the same metadata
    # Default to applying everything.  PT_security_only comes in from puppet tasks
    case $PT_security_only in
      true)
        SECONLY="--security"
        ${LOGGER} "patch task will only apply updates marked as security related"
      ;;
      *)
        SECONLY=""
        ${LOGGER} "patch task will apply all updates"
      ;;
    esac

    # Do we have any updates?
    yum clean all 2>/dev/null 1>/dev/null
    ${LOGGER} "yum clean complete"
    yum ${SECONLY} check-update 2>/dev/null 1>/dev/null
    case ${?} in
      0)
        ${LOGGER} "No updates found, exiting cleanly"
        ENDDATE=$(date)
        JSON=$(cat <<EOF
{
  "fqdn": "${FQDN}",
  "return-code": "Success",
  "startdate": "${STARTDATE}",
  "enddate": "${ENDDATE}",
  "message": "yum shows no patching work to do",
  "reboot": "${PT_reboot}",
  "securityonly": "${PT_security_only}"
}
EOF
)
        echo "${JSON}"
        exit 0
      ;;
      100)
          # Yes there are updates to apply
          ${LOGGER} 'updates to apply'
      ;;
      *)
        ${LOGGER} "failure checking updates"
        exit 1
      ;;
    esac
  
    # Actually do the patching!
    ${LOGGER} "applying updates"
    yum ${SECONLY} upgrade -y 2>/dev/null 1>dev/null
    if [ "$?" -lt 1 ]
    then
      MESSAGE="Patching complete"
      JOB=`yum history | grep -E "^[[:space:]]" | awk '{print $1}' | head -1`
      RETURN=`yum history info "${JOB}" | awk '$1 == "Return-Code" {print $3}'`
      PACKAGES=`yum history info "${JOB}" | grep -E "Updated" | awk '{print t "\"" $2 "\""} { t=", "}'`
    else
      MESSAGE="Yum completed with errors"
      RETURN="Error"
    fi
  ;;
  Debian)
    # The security only tagging works with RHEL with an official
    # feed from Redhat.  CentOS doesn't seem to have the same metadata
    # Default to applying everything.  PT_security_only comes in from puppet tasks
    case $PT_security_only in
      true)
        ${LOGGER} "patch task will only apply updates marked as security related"
        PACKAGES=$(apt-get upgrade -s | awk '$1 == "Inst" && /security/ {print $2}')
        if [ "$SECKPGS" -gt 0 ]
        then
          ${LOGGER} "applying security updates"
          apt-get upgrade -s | awk '$1 == "Inst" && /security/ {print $2}' | xargs apt -qy install 2>/dev/null 1>/dev/null
          RET=$?
	      else
	        RET=-1
        fi
      ;;
      *)
        ${LOGGER} "applying all updates"
        PACKAGES=$(apt-get upgrade -s | awk '$1 == "Inst" {print $2}')
	      if [ -n "$PACKAGES" ]
      	then
          apt-get -qy upgrade 2>/dev/null 1>/dev/null
          RET=$?
	      else
		      RET=-1
	      fi
      ;;
    esac

    if [ "$RET" -eq 1 ]
    then
      MESSAGE="Patching complete"
      RETURN='Success'
    elif [ "$RET" -eq -1 ]
    then
      MESSAGE="No updates required"
      RETURN='Success'
    else
      MESSAGE="apt completed with errors"
      RETURN="Error"
    fi
  ;;
esac

${LOGGER} $MESSAGE
ENDDATE=$(date)

JSON=$(cat <<EOF
{
  "fqdn": "${FQDN}",
  "return-code": "${RETURN}",
  "startdate": "${STARTDATE}",
  "enddate": "${ENDDATE}",
  "packagesupdated": [
    ${PACKAGES}
  ],
  "reboot": "${PT_reboot}",
  "securityonly": "${PT_security_only}",
  "message": "${MESSAGE}"
}
EOF
)

echo "${JSON}"

${LOGGER} "refreshing facts and running puppet"
/usr/local/bin/os_patching_fact_generation.sh
puppet agent -t 2>/dev/null 1>/dev/null

if [ "${REBOOT}" -gt 0 ]
then
  # Reboot option set to true, reboot the system
  ${LOGGER} "triggering reboot in 1 minute"
  /sbin/shutdown -r 1
else
  ${LOGGER} "not rebooting based on task parameter"
fi

${LOGGER} "patch run complete"
exit 0
