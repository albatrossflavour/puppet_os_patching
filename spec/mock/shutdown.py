#!/usr/bin/env python
import argparse
import sys
parser = argparse.ArgumentParser("Mock shutdown command")
parser.add_argument('-r')
args = parser.parse_args()

reboot_state = "/tmp/os_patching/system_rebooted.txt"
if args.r:
    res = 'OK'
    print("shutdown: system would have rebooted")
else:
    print("incorrect shutdown invocation:")
    res = "ERROR: " + " ".join(sys.argv[1:])

with open(reboot_state, 'w') as f:
    f.write(res)
