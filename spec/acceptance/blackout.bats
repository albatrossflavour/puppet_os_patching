@test "update didnt run due to blackout" {
    grep "Patching blocked" /tmp/output.txt
}