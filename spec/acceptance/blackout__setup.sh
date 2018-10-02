
sh /testcase/spec/acceptance/setup.sh
puppet apply /testcase/examples/init.pp
# mark the next ~day as a blackout
cat << END > /var/cache/os_patching/blackout_windows
test blackout,$(date --iso-8601=seconds | sed 's/\d(\d{,2})$/0:$1/'),$(date --iso-8601=seconds --date  "09:00 tomorrow" | sed 's/\d(\d{,2})$/0:$1/')
END
