#!/usr/bin/env python
# Mock version of apt-get
import argparse
import sys
parser = argparse.ArgumentParser("Mock apt-get command")
parser.add_argument('command',  metavar='COMMAND')
parser.add_argument('--no-install-recommends', action="store_true")
parser.add_argument('-y', action="store_true", help="yes to all questions")
parser.add_argument('-o', action='append', help="option")
parser.add_argument('-s', action="store_true", help="simulate")
parser.add_argument('-a', help="architecture")
#dpkg clean

args = parser.parse_args()

mock_simulate="""NOTE: This is only a simulation!
      apt-get needs root privileges for real execution.
      Keep also in mind that locking is deactivated,
      so don't depend on the relevance to the real current situation!
Reading package lists... Done
Building dependency tree
Reading state information... Done
Calculating upgrade... Done
The following packages will be upgraded:
  initramfs-tools initramfs-tools-bin initramfs-tools-core python3-update-manager
  python3-urllib3 update-manager-core
6 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
Inst initramfs-tools [0.122ubuntu8.11] (0.122ubuntu8.12 Ubuntu:16.04/xenial-updates [all]) []
Inst initramfs-tools-core [0.122ubuntu8.11] (0.122ubuntu8.12 Ubuntu:16.04/xenial-updates [all]) []
Inst initramfs-tools-bin [0.122ubuntu8.11] (0.122ubuntu8.12 Ubuntu:16.04/xenial-updates [amd64])
Inst python3-update-manager [1:16.04.13] (1:16.04.14 Ubuntu:16.04/xenial-updates [all]) [update-manager-core:amd64 ]
Inst update-manager-core [1:16.04.13] (1:16.04.14 Ubuntu:16.04/xenial-updates [all])
Inst python3-urllib3 [1.13.1-2ubuntu0.16.04.1] (1.13.1-2ubuntu0.16.04.2 Ubuntu:16.04/xenial-updates [all])
Conf initramfs-tools-bin (0.122ubuntu8.12 Ubuntu:16.04/xenial-updates [amd64])
Conf initramfs-tools-core (0.122ubuntu8.12 Ubuntu:16.04/xenial-updates [all])
Conf initramfs-tools (0.122ubuntu8.12 Ubuntu:16.04/xenial-updates [all])
Conf python3-update-manager (1:16.04.14 Ubuntu:16.04/xenial-updates [all])
Conf update-manager-core (1:16.04.14 Ubuntu:16.04/xenial-updates [all])
Conf python3-urllib3 (1.13.1-2ubuntu0.16.04.2 Ubuntu:16.04/xenial-updates [all])
"""

if args.command == 'dist-upgrade' or args.command == 'upgrade':
    print("mock: apt-get %s would have run" % args.command)
    if args.s:
        print(mock_simulate)
    else:
        with open("/tmp/os_patching/system_updated.txt", 'w') as f:
            if args.o:
                f.write("\n".join(args.o))
            if args.a:
                f.write("\n" + args.a)
elif args.command == 'update':
    print("mock: apt-get update would have run")
    with open("/tmp/os_patching/metadata_update.txt", 'w') as f:
        f.write("updated")
else:
    print("incorrect apt-get invocation:")
    print(" ".join(sys.argv[1:]))
    sys.exit(1)
