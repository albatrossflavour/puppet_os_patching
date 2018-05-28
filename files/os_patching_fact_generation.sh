#!/bin/sh
#
# Generate cache of patch data for consumption by Puppet custom facts.
#

PATH=/usr/bin:/usr/sbin:/bin:/usr/local/bin

FACTFILE=/opt/puppetlabs/facter/facts.d/os_patching.yaml
COUNT=0

echo -e "---\nos_patching:\n  package_updates:" > ${FACTFILE}


for UPDATE in `yum -q check-update | awk '{print $1}'`
do
  echo "   - '$UPDATE'" >> ${FACTFILE}
  COUNT=`expr $COUNT + 1`
done

SECCOUNT=0
echo "  security_package_updates:" >> ${FACTFILE}
for UPDATE in `yum -q --security check-update | awk '{print $1}'`
do
  echo "   - '$UPDATE'" >> ${FACTFILE}
  SECCOUNT=`expr $SECCOUNT + 1`
done

echo "  package_update_count: $COUNT" >> ${FACTFILE}
echo "  security_package_update_count: $SECCOUNT" >> ${FACTFILE}
exit 0
