@test "update didnt run due to blackout" {
    grep "Patching blocked" /tmp/os_patching/output.txt
}