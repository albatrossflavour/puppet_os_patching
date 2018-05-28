#!/bin/sh

PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin
export PATH
REBOOT=0
SECONLY=""
FQDN=$(facter fqdn)
JSONDATE=$(date)

# Default to not rebooting.  PT_reboot comes in from puppet tasks
case $PT_reboot in
  true)  REBOOT=1 ;;
  false) REBOOT=0 ;;
  *)     REBOOT=0 ;;
esac

# The security only tagging works with RHEL with an official
# feed from Redhat.  CentOS doesn't seem to have the same metadata
# Default to applying everything.  PT_security_only comes in from puppet tasks
case $PT_security_only in
  true)  SECONLY="--security" ;;
  false) SECONLY="" ;;
  *)     SECONLY="" ;;
esac

# Do we have any updates?
yum clean all 2>/dev/null 1>/dev/null
yum $SECONLY check-update 2>/dev/null 1>/dev/null
case $? in
  0)
    JSON=$(cat <<EOF
{
  "fqdn": "$FQDN",
  "return-code": "Success",
  "date": "$JSONDATE",
  "message": "yum shows no patching work to do",
  "reboot": "$PT_reboot",
  "securityonly": "$PT_security_only"
}
EOF
)
    echo "$JSON"
    exit 0
  ;;
  100)
      # Yes there are updates to apply
      MESSAGE='updates to apply'
  ;;
  *)
    echo "Failed"
    exit 1
  ;;
esac

# Actually do the patching!
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



JSON=`cat <<EOF
{
  "fqdn": "${FQDN}",
  "return-code": "${RETURN}",
  "date": "${JSONDATE}",
  "packagesupdated": [
    ${PACKAGES}
  ],
  "reboot": "${PT_reboot}",
  "securityonly": "${PT_security_only}",
  "message": "${MESSAGE}"
}
EOF
`

echo "$JSON"

/usr/local/bin/os_patching_fact_generation.sh
puppet agent -t 2>/dev/null 1>/dev/null

if [ "$REBOOT" -gt 0 ]
then
  # Reboot option set to true, reboot the system
  /sbin/shutdown -r 1
fi

exit 0
