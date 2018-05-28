#!/bin/sh

PATH=/bin:/usr/bin:/sbin:/usr/local/bin

if [ "$(facter osfamily)" != "RedHat" ]
then
  RETURN="Not a Redhat system, exiting"
  exit 0
else
  yum check-update 2>/dev/null 1>/dev/null

  case $? in
    0) RETURN="No updates available" ;;
    100)
       RETURN="Updates available"
       # Force fact regeneration
       /usr/local/bin/os_patching_fact_generation.sh
    ;;
    *) RETURN="Unknown state"        ;;
  esac
fi

JSON="{ \"message\": \"$RETURN\" }"
echo $JSON
exit 0
