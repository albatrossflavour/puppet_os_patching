sh /testcase/spec/acceptance/setup.sh
puppet apply /testcase/examples/init.pp
start=$(date --iso-8601=seconds | sed 's/\([[:digit:]]\)\([[:digit:]]\{2\}\)$/\1:\2/')
end=$(date --iso-8601=seconds --date  "09:00 tomorrow" | sed 's/\([[:digit:]]\)\([[:digit:]]\{2\}\)$/\1:\2/')
# mark the next ~day as a blackout
cat << END > /var/cache/os_patching/blackout_windows
test blackout,$start,$end
END
