#!/bin/sh
#
# Generate cache of patch data for consumption by Puppet custom facts.
#

PATH=/usr/bin:/usr/sbin:/bin:/usr/local/bin

LOCKFILE=/var/run/os_patching_fact_generation.lock

if [ -f "$LOCKFILE" ]
then
  echo "Locked, exiting" >&2
  exit 0
else
  echo "$$" > $LOCKFILE
fi

case $(/usr/local/bin/facter osfamily) in
  RedHat)
    PKGS=$(yum -q check-update | awk '/^[a-z]/ {print $1}')
    SECPKGS=$(yum -q --security check-update | awk '/^[a-z]/ {print $1}')
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

DATADIR='/etc/os_patching'
UPDATEFILE="$DATADIR/package_updates"
SECUPDATEFILE="$DATADIR/security_package_updates"

if [ ! -d "${DATADIR}" ]
then
  /usr/bin/logger -p error -t os_patching_fact_generation.sh "Can't find ${DATADIR}, exiting"
  rm $LOCKFILE
  exit 1
fi

cat /dev/null > ${UPDATEFILE}
for UPDATE in $PKGS
do
  echo "$UPDATE" >> ${UPDATEFILE} || exit 1
done

cat /dev/null > ${SECUPDATEFILE}
for UPDATE in $SECPKGS
do
  echo "$UPDATE" >> ${SECUPDATEFILE} || exit 1
done

if [ -f '/usr/bin/needs-restarting' ]
then
  case $(facter os.release.major) in
    7)
      /usr/bin/needs-restarting -r 2>/dev/null 1>/dev/null
      if [ $? -gt 0 ]
      then
        echo "true" > /etc/os_patching/reboot_required
      else
        echo "false" > /etc/os_patching/reboot_required
      fi
      /usr/bin/needs-restarting 2>/dev/null >/etc/os_patching/apps_to_restart
    ;;
    6)
      OUTPUT=`/usr/bin/needs-restarting`
      if [ -n "$OUTPUT" ]
      then
        echo "true" > /etc/os_patching/reboot_required
        /usr/bin/needs-restarting > /etc/os_patching/apps_to_restart
      else
        echo "false" > /etc/os_patching/reboot_required
        echo "" > /etc/os_patching/apps_to_restart
      fi
    ;;
  esac
fi

/opt/puppetlabs/bin/puppet facts upload 2>/dev/null 1>/dev/null
/usr/bin/logger -p info -t os_patching_fact_generation.sh "patch data fact refreshed"

rm $LOCKFILE
exit 0
