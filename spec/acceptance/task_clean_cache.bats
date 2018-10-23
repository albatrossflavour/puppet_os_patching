@test "metadata was updated" {
    grep updated /tmp/os_patching/metadata_update.txt
}

@test "clean cache - timeouts propagated OK" {
    # 1x clean
    [[ $(grep "timeout=15" /tmp/os_patching/output.txt | wc -l) -eq 1 ]]
}