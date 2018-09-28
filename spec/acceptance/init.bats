@test "/opt/puppetlabs/facter/facts.d/os_patching.yaml removed" {
    test -f /opt/puppetlabs/facter/facts.d/os_patching.yaml
}

@test "/var/cache/os_patching removed" {
    test -d /var/cache/os_patching
}

@test "/usr/local/bin/os_patching_fact_generation.sh installed" {
    test -f /usr/local/bin/os_patching_fact_generation.sh
}

@test "cache patching data cron job installed" {
    (cat /var/spool/cron/root || cat /var/spool/cron/crontabs/root ) | grep -i "Cache patching data"
}

@test "catch patching data at reboot cron job installed" {
    (cat /var/spool/cron/root || cat /var/spool/cron/crontabs/root ) | grep -i "Cache patching data at reboot"
}

@test "reboot_override set to smart" {
    grep smart '/var/cache/os_patching/reboot_override'
}

@test "patch_window set to Week3" {
    grep Week3 '/var/cache/os_patching/patch_window'
}

@test "end of year blackout saved" {
    grep "End of year change freeze,2018-12-15T00:00:00+10:00,2019-01-15T23:59:59+10:00" /var/cache/os_patching/blackout_windows
}

@test "end of DST blackout saved" {
    grep "End of DST,2019-04-07T00:00:00+10:00,2019-04-08T23:59:59+10:00" /var/cache/os_patching/blackout_windows
}
