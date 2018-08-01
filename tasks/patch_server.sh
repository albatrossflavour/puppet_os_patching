#!/bin/bash

PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin
FQDN=$(facter fqdn)
FAMILY=$(facter osfamily)
STARTDATE=$(date)
LOGGER='/usr/bin/logger -p info -t os_patching'
PINNEDPKGS=$(facter -p os_patching.pinned_packages 2>/dev/null)
if [ -z "${PINNEDPKGS}" ]
then
  PINNEDPKGS='""'
fi
${LOGGER} "Starting patch run task"

# Default to not rebooting.  PT_reboot comes in from puppet tasks
case ${PT_reboot} in
  true)  REBOOT=1 ;;
  *)     REBOOT=0 ;;
esac

# Default to patching everything.  PT_security_only comes in from puppet tasks
case ${PT_security_only} in
  true)  PT_security_only=true ;;
  *)     PT_security_only=false ;;
esac

${LOGGER} "patch task set post run reboot to $PT_reboot"

function output()
{
  RETURN=$1
  MESSAGE=$2
  PACKAGES=$3
  ENDDATE=$(date)
  JSON=$(cat <<EOF
{
  "fqdn": "${FQDN}",
  "return-code": "${RETURN}",
  "startdate": "${STARTDATE}",
  "enddate": "${ENDDATE}",
  "reboot": "${PT_reboot}",
  "securityonly": "${PT_security_only}",
  "message": "${MESSAGE}",
  "packagesupdated": [
    ${PACKAGES}
  ],
  "pinned_packages" : ${PINNEDPKGS}
}
EOF
)
  echo "${JSON}"
  PATCHDATE=$(date -Isec)
  echo -e "${PATCHDATE}\t${MESSAGE}\t${RETURN}\t${PT_reboot}\t${PT_security_only}" >> /etc/os_patching/run_history
}

# Check if patching is blocked
if [ $(facter -p os_patching.blocked) == true ]
then
  REASONS=$(facter -p os_patching.blocked_reasons | awk '/"/ {printf $0}' | sed "s/\"/'/g")
  output "Blocked" "Patching is blocked : $REASONS"
  ${LOGGER} "patching is blocked, exiting"
  exit 1
fi

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
        output "Success" "yum shows no patching work to do"
        exit 0
      ;;
      100)
          # Yes there are updates to apply
          ${LOGGER} 'updates to apply'
      ;;
      *)
        ${LOGGER} "failure checking updates"
        output "Error" "Could not check updates though yum"
        exit 1
      ;;
    esac

    # Actually do the patching!
    ${LOGGER} "applying updates"
    yum ${SECONLY} upgrade -y 2>/dev/null 1>dev/null
    if [ "$?" -lt 1 ]
    then
      MESSAGE="Patching complete"
      JOB=$(yum history | grep -E "^[[:space:]]" | awk '{print $1}' | head -1)
      RETURN=$(yum history info "${JOB}" | awk '$1 == "Return-Code" {print $3}')
      PACKAGES=$(yum history info "${JOB}" | grep -E "Updated" | awk '{print t "\"" $2 "\""} { t=", "}')
    else
      MESSAGE="Yum completed with errors"
      RETURN="Error"
      REBOOT=0
    fi
  ;;
  Debian)
    # Match packages from security repos to see if there are any security updates to apply.
    # Default to applying everything.  PT_security_only comes in from puppet tasks
    case $PT_security_only in
      true)
        ${LOGGER} "patch task will only apply updates marked as security related"
        PACKAGES=$(apt upgrade -s 2>/dev/null| awk '$1 == "Inst" && /security/ {{print t "\"" $2 "\""} { t=", "}}')
        if [ -n "${PACKAGES}" ]
        then
          ${LOGGER} "applying security updates"
          apt upgrade -s 2>/dev/null | \
            awk '$1 == "Inst" && /security/ {print $2}' | \
            xargs apt -qy install 2>/dev/null 1>/dev/null
          RET=$?
	      else
	        RET=-1
        fi
      ;;
      *)
        ${LOGGER} "applying all updates"
        PACKAGES=$(apt-get upgrade -s | awk '$1 == "Inst" {{print t "\"" $2 "\""} { t=", "}}')
	      if [ -n "$PACKAGES" ]
      	then
          apt -qy upgrade 2>/dev/null 1>/dev/null
          RET=$?
	      else
		      RET=-1
	      fi
      ;;
    esac

    if [ "$RET" -eq 0 ]
    then
      MESSAGE="Patching complete"
      RETURN='Success'
    elif [ "$RET" -eq -1 ]
    then
      MESSAGE="No updates required"
      RETURN='Success'
      REBOOT=0
    else
      MESSAGE="apt completed with errors"
      RETURN="Error"
      REBOOT=0
    fi
  ;;
esac

${LOGGER} "$MESSAGE"

output "${RETURN}" "${MESSAGE}" "${PACKAGES}"

${LOGGER} "refreshing facts and running puppet"

if [ -f '/usr/local/bin/os_patching_fact_generation.sh' ]
then
  /usr/local/bin/os_patching_fact_generation.sh
fi
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
