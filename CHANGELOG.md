# Changelog

## Release 0.3.1

- A new fact (reboots) is available.
  - reboots.reboot_required shows if the OS belives it needs to be restarted
  - app_restart_required shows if the OS can detect and processes using previously patched files
  - apps_needing_restart is a hash of the PID and command line of those processes
- Reboots integrated into patching task
- Documentation and examples updated

## Release 0.2.1

- Major rewrite on most areas of the module
- Patching task now written in ruby and has much better reporting and error handling
- Facter is now ruby based but still uses cache data from a cron job
- Blackout window functionality included
- Documentation updates
- SHOULD be backwards compatible

## Release 0.1.19

- Bugfix on the debian task which caused incorrect reporting of patching status

## Release 0.1.18

- Many improvements in the debian workflow
- Pull out information for pinned/version locked/held packages
- Removed redundant task
- Cleaner patch fact generation

## Release 0.1.17

- Added initial support for Debian/Ubuntu systems

## Release 0.1.16

- Additional logging, through `logger`, on both fact generation and patching
- Clean up of the puppet manifest
- Add all of the cron schedule options as parameters
- Add security update reporting (requires a RHEL subscription)
- Automatically re-run the fact script during the puppet run if it changes

## Release 0.1.15

- Rewrite of patch facts and tasks

