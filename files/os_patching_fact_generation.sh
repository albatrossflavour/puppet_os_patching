#!/bin/sh
#
# Generate cache of patch data for consumption by Puppet custom facts.
#

PATH=/usr/bin:/usr/sbin:/bin:/usr/local/bin

FACTDIR='/opt/puppetlabs/facter/facts.d'
FACTFILE="${FACTDIR}//os_patching.yaml"
COUNT=0

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

case $(/usr/local/bin/facter osfamily) in
  RedHat)
    PKGCMD="yum -q check-update | awk '{print $1}'"
    SECPKGCMD="yum -q --security check-update | awk '{print $1}'"
  ;;
  Debian)
    PKGCMD="apt-get upgrade -s | awk '$1 == "Inst" {print $2}"
    SECPKGCMD="apt-get upgrade -s | awk '$1 == "Inst && /security/" {print $2}"
  ;;
  Windows)
  ;;
  *)
  ;;
esac
echo "os_patching:" >> ${FACTFILE} || exit 1
echo "  package_updates:" >> ${FACTFILE} || exit 1
for UPDATE in $(PKGCMD)
do
  echo "   - '$UPDATE'" >> ${FACTFILE} || exit 1
  COUNT=$((COUNT + 1))
done

SECCOUNT=0
echo "  security_package_updates:" >> ${FACTFILE} || exit 1
for UPDATE in $(SECPKGCMD)
do
  echo "   - '$UPDATE'" >> ${FACTFILE} || exit 1
  SECCOUNT=$((SECCOUNT + 1))
done

echo "  package_update_count: $COUNT" >> ${FACTFILE} || exit 1
echo "  security_package_update_count: $SECCOUNT" >> ${FACTFILE} || exit 1

/usr/bin/logger -p info -t os_patching_fact_generation.sh "patch data fact refreshed"

exit 0
