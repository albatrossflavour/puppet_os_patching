#!/usr/bin/env python
import argparse
import sys
from time import strftime
import os.path
import time

ts = strftime("%Y-%m-%d %H:%M")


yum_hist = """Loaded plugins: fastestmirror
ID     | Login user               | Date and time    | Action(s)      | Altered
-------------------------------------------------------------------------------
  69 | puppet                   | %s | Install        |    6
   6 | vagrant <vagrant>        | 2018-09-20 02:09 | Install        |    6
   5 | vagrant <vagrant>        | 2018-09-12 07:00 | Install        |    1
   4 | vagrant <vagrant>        | 2018-05-21 00:08 | Install        |   36
   3 | vagrant <vagrant>        | 2018-03-24 21:40 | Erase          |    7
   2 | vagrant <vagrant>        | 2018-03-24 14:36 | I, U           |   48
   1 | System <unset>           | 2018-03-24 14:34 | Install        |  231
history list""" % ts

yum_job = """Loaded plugins: fastestmirror
Transaction ID : 6
Begin time     : Thu Sep 20 02:09:57 2018
Begin rpmdb    : 263:a2ba75a523ad91a8e7abd146fcd154749d582aa0
End time       :                           (0 seconds)
End rpmdb      : 269:f9311d83a256b27b16960ac68118156f727a811f
User           : vagrant <vagrant>
Return-Code    : Success
Command Line   : install python-requests
Transaction performed with:
    Installed     rpm-4.8.0-55.el6.x86_64                       @anaconda-CentOS-201703281317.x86_64/6.9
    Installed     yum-3.2.29-81.el6.centos.noarch               @anaconda-CentOS-201703281317.x86_64/6.9
    Installed     yum-plugin-fastestmirror-1.1.30-40.el6.noarch @anaconda-CentOS-201703281317.x86_64/6.9
    Installed     initramfs-tools-core.elfake.noarch            @fakefake-fakexx-999999999999.x86_64/9.9
Packages Altered:
    Dep-Install python-backports-1.0-5.el6.x86_64                        @base
    Dep-Install python-backports-ssl_match_hostname-3.4.0.2-5.el6.noarch @base
    Dep-Install python-chardet-2.2.1-1.el6.noarch                        @base
    Install     python-requests-2.6.0-4.el6.noarch                       @base
    Dep-Install python-six-1.9.0-2.el6.noarch                            @base
    Dep-Install python-urllib3-1.10.2-3.el6.noarch                       @base
history info
"""

yum_outdated = """
NetworkManager.x86_64                        1:1.10.2-16.el7_5                      updates
NetworkManager-libnm.x86_64                  1:1.10.2-16.el7_5                      updates
NetworkManager-team.x86_64                   1:1.10.2-16.el7_5                      updates
NetworkManager-tui.x86_64                    1:1.10.2-16.el7_5                      updates
NetworkManager-wifi.x86_64                   1:1.10.2-16.el7_5                      updates
acl.x86_64                                   2.2.51-14.el7                          base
audit.x86_64                                 2.8.1-3.el7_5.1                        updates
"""

parser = argparse.ArgumentParser("Mock yum command")
parser.add_argument('-y', action='store_true')
parser.add_argument('-q', action='store_true')
parser.add_argument('--security', action='store_true')
parser.add_argument('--errorlevel')
parser.add_argument('command',  metavar='COMMAND')
parser.add_argument('info',  metavar='INFO', nargs='?')
parser.add_argument('id',  metavar='ID', nargs='?')
#parser.add_argument('history', nargs='?')
args = parser.parse_args()

print(args.command)
if args.command == 'upgrade':
    with open("/tmp/os_patching/system_updated.txt", 'w') as f:
        if args.errorlevel:
            f.write("errorlevel=" + args.errorlevel)
elif args.command == 'history':
    if args.id and args.info:
        print(yum_job)
    else:
        print(yum_hist)
elif args.command == 'clean':
    print("clean metadata")
    with open("/tmp/os_patching/metadata_update.txt", 'w') as f:
        f.write("updated")
elif args.command == 'check-update':
    if args.security:
        # security updates only
        print("security updates test -- todo")
    else:
        print(yum_outdated)
else:
    print("incorrect yum invocation:")
    print(" ".join(sys.argv[1:]))
    sys.exit(1)