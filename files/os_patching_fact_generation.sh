#!/bin/sh
#
# Generate cache of patch data for consumption by Puppet custom facts.
#

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/bin:/usr/local/bin:/usr/local/sbin:/opt/puppetlabs/puppet/bin:/opt/puppetlabs/bin

LOCKFILE=/var/run/os_patching_fact_generation.lock

trap "{ rm -f $LOCKFILE ; exit 255; }" 2 3 15

if [ -f "$LOCKFILE" ]
then
  echo "Locked, exiting" >&2
  exit 0
else
  echo "$$" > $LOCKFILE
fi

case $(facter osfamily) in
  RedHat)
    # Sometimes yum check-update will output extra info like this:
    # ---
    # Security: kernel-3.14.6-200.fc20.x86_64 is an installed security update
    # Security: kernel-3.14.2-200.fc20.x86_64 is the currently running version
    # ---
    # We need to filter those out as they screw up the package listing
    FILTER='egrep -v "^Security:"'
    PKGS=$(yum -q check-update 2>/dev/null| $FILTER | egrep -v "is broken" | awk '/^[[:alnum:]]/ {print $1}')
    SECPKGS=$(yum -q --security check-update 2>/dev/null| $FILTER | egrep -v "is broken" | awk '/^[[:alnum:]]/ {print $1}')
  ;;
  Debian)
    PKGS=$(apt upgrade -s 2>/dev/null | awk '$1 == "Inst" {print $2}')
    SECPKGS=$(apt upgrade -s 2>/dev/null | awk '$1 == "Inst" && /security/ {print $2}')
  ;;
  *)
    rm $LOCKFILE
    exit 1
  ;;
esac

DATADIR='/var/cache/os_patching'
UPDATEFILE="$DATADIR/package_updates"
SECUPDATEFILE="$DATADIR/security_package_updates"

if [ ! -d "${DATADIR}" ]
then
  logger -p error -t os_patching_fact_generation.sh "Can't find ${DATADIR}, exiting"
  rm $LOCKFILE
  exit 1
fi

cat /dev/null > ${UPDATEFILE}
for UPDATE in $PKGS
do
  echo "$UPDATE" >> ${UPDATEFILE}
done

cat /dev/null > ${SECUPDATEFILE}
for UPDATE in $SECPKGS
do
  echo "$UPDATE" >> ${SECUPDATEFILE}
done

if [ -f '/usr/bin/needs-restarting' ]
then
  case $(facter os.release.major) in
    7)
      /usr/bin/needs-restarting -r 2>/dev/null 1>/dev/null
      if [ $? -gt 0 ]
      then
        echo "true" > $DATADIR/reboot_required
      else
        echo "false" > $DATADIR/reboot_required
      fi
      /usr/bin/needs-restarting 2>/dev/null | sed 's/[[:space:]]*$//' >$DATADIR/apps_to_restart
    ;;
    6)
      /usr/bin/needs-restarting 2>/dev/null 1>$DATADIR/apps_to_restart
      if [ $? -gt 0 ]
      then
        echo "true" > $DATADIR/reboot_required
      else
        APPS_TO_RESTART=$(wc -l $DATADIR/apps_to_restart | awk '{print $1}')
        if [ $APPS_TO_RESTART -gt 0 ]
        then
          echo "true" > $DATADIR/reboot_required
        else
          echo "false" > $DATADIR/reboot_required
        fi
      fi
    ;;
  esac
fi

if [ $(facter osfamily) = 'Debian' ]
then
  if [ -f '/var/run/reboot-required' ]
  then
    echo "true" > $DATADIR/reboot_required
  else
    echo "false" > $DATADIR/reboot_required
  fi
fi

puppet facts upload 2>/dev/null 1>/dev/null
logger -p info -t os_patching_fact_generation.sh "patch data fact refreshed"

rm $LOCKFILE
exit 0
