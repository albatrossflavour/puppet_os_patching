
sh /testcase/spec/acceptance/setup.sh
puppet apply /testcase/examples/init.pp
# mark the next ~day as a blackout
cat << END > /etc/os_patching/blackout_windows
test blackout,$(date --iso-8601=seconds),$(date --iso-8601=seconds --date  "09:00 tomorrow")
END