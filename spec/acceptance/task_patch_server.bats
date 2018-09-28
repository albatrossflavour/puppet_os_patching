@test "mock reports system update" {
    ls /tmp/os_patching/system_updated.txt
}

@test "task reports packages updated" {
    grep "initramfs-tools" /tmp/os_patching/output.txt
}

@test "task reports success" {
    grep '"return": "Success"' /tmp/os_patching/output.txt
}

@test "mock reports system was rebooted" {
    grep OK /tmp/os_patching/system_rebooted.txt
}

@test "options specified are used" {
    os=$(facter os.family)

    if [ "$os" == "Debian" ] ; then
        mark="i386"
    elif [ "$os" == "RedHat" ] ; then
        mark="errorlevel"
    else
        echo "unsupported OS in testcase: ${os}"
    fi
    grep $mark /tmp/os_patching/system_updated.txt
}