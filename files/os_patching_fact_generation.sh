#!/bin/sh
#
# Generate cache of patch data for consumption by Puppet custom facts.
#

PATH=/usr/bin:/usr/sbin:/bin:/usr/local/bin

case $(/usr/local/bin/facter osfamily) in
  RedHat)
    PKGS=$(yum -q check-update | awk '/^[a-z]/ {print $1}')
    SECPKGS=$(yum -q --security check-update | awk '/^[a-z]/ {print $1}')
    PINNEDPKGS=$(awk -F: '/^[0-9]*:/ {print $2}' /etc/yum/pluginconf.d/versionlock.list 2>/dev/null )
  ;;
  Debian)
    PKGS=$(apt upgrade -s 2>/dev/null | awk '$1 == "Inst" {print $2}')
    SECPKGS=$(apt upgrade -s 2>/dev/null | awk '$1 == "Inst" && /security/ {print $2}')
    PINNEDPKGS=$(awk '$1 == "Package:" {print $2}' /etc/apt/preferences.d/hold*pref)
  ;;
  *)
    exit 1
  ;;
esac

FACTDIR='/opt/puppetlabs/facter/facts.d'
FACTFILE="${FACTDIR}//os_patching.yaml"

if [ ! -d "${FACTDIR}" ]
then
  /usr/bin/logger -p error -t os_patching_fact_generation.sh "Can't find ${FACTDIR}, exiting"
  exit 1
fi

echo "---" > ${FACTFILE}
if [ "$?" -gt 1 ]
then
  /usr/bin/logger -p error -t os_patching_fact_generation.sh "Can't write to ${FACTFILE}, exiting"
  exit 1
fi

echo "os_patching:" >> ${FACTFILE} || exit 1

COUNT=0
echo "  package_updates:" >> ${FACTFILE} || exit 1
for UPDATE in $PKGS
do
  echo "   - '$UPDATE'" >> ${FACTFILE} || exit 1
  COUNT=$((COUNT + 1))
done

SECCOUNT=0
echo "  security_package_updates:" >> ${FACTFILE} || exit 1
for UPDATE in $SECPKGS
do
  echo "   - '$UPDATE'" >> ${FACTFILE} || exit 1
  SECCOUNT=$((SECCOUNT + 1))
done

echo "  package_update_count: $COUNT" >> ${FACTFILE} || exit 1
echo "  security_package_update_count: $SECCOUNT" >> ${FACTFILE} || exit 1


# Do we have pinned packages?
if [ -n "$PINNEDPKGS" ]
then
  echo "  pinned_packages:" >> ${FACTFILE} || exit 1
  for PKG in $PINNEDPKGS
  do
    echo "   - '$PKG'" >> ${FACTFILE} || exit 1
  done
fi

# Are we blocked? (os_patching::block)
BLOCKCONF=/etc/os_patching/block.conf

if [ -f "$BLOCKCONF" ]
then
  . /etc/os_patching/block.conf

  echo "  patching_blocked: $BLOCK" >> ${FACTFILE} || exit 1
  echo "  patching_blocked_reason: $REASON" >> ${FACTFILE} || exit 1
fi

/usr/bin/logger -p info -t os_patching_fact_generation.sh "patch data fact refreshed"

exit 0
