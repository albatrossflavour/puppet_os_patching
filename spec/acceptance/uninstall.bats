
@test "/var/cache/os_patching removed" {
    ! test -d /var/cache/os_patching
}

@test "/usr/local/bin/os_patching_fact_generation.sh removed" {
    ! test -f /usr/local/bin/os_patching_fact_generation.sh
}

@test "cache patching data cron job removed" {
    ! ((cat /var/spool/cron/root || cat /var/spool/cron/crontabs/root ) | grep -i "Cache patching data")
}

@test "catch patching data at reboot cron job removed" {
    ! ((cat /var/spool/cron/root || cat /var/spool/cron/crontabs/root ) | grep -i "Cache patching data at reboot")
}

@test "blackout_windows_file removed" {
    ! test -f /var/cache/os_patching/blackout_windows
}

@test "reboot_override file removed" {
    ! test -f '/var/cache/os_patching/reboot_override'
}
