
@test "refresh facts - timeouts propagated OK" {
    # 1x facter runs
    [[ $(grep "timeout=15" /tmp/os_patching/output.txt | wc -l) -eq 1 ]]
}