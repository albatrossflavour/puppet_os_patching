#!/bin/sh
#
# Generate cache of patch data for consumption by Puppet custom facts.
#

PATH=/usr/bin:/usr/sbin:/bin:/usr/local/bin

LOCKFILE=/var/run/os_patching_fact_generation.lock

lockfile -r 0 $LOCKFILE

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

if [ -f '/bin/needs-restarting' ]
then
  /bin/needs-restarting -r 2>/dev/null 1>/dev/null
  if [ $? -gt 0 ]
  then
    echo "true" > /etc/os_patching/reboot_required
  else
    echo "false" > /etc/os_patching/reboot_required
  fi
  /bin/needs-restarting 2>/dev/null >/etc/os_patching/apps_to_restart
fi

/opt/puppetlabs/bin/puppet facts upload 2>/dev/null 1>/dev/null
/usr/bin/logger -p info -t os_patching_fact_generation.sh "patch data fact refreshed"

rm $LOCKFILE
exit 0
