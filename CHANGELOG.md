# Changelog

## Release 0.5.0

- Rewrite of the reboot logic for both the task and the `reboot_override` fact.  **SHOULD** be backward compatable with how things used to work but it's now much cleaner and clearer.
- Updated logging, documentation and comments

## Release 0.4.1

- Missed some metadata info updates in 0.4.0

## Release 0.4.0

- Some [issues](https://github.com/albatrossflavour/puppet_os_patching/issues/36) found with the use of needs-restarting on RHEL6 based systems under certain circumstances.  Updated the tasks and facts to cope with it.
- Ensure lock file is cleaned up if the os_patching_fact_generation.sh script is interupted or killed.
- Fix the regex matching for packages that start with a numeric or a capital letter
- Add a new 'warning' entry in the os_patching fact to allow highlighting of potential issues (cache files not updated in a while or not present)
- Catch times when yum would exit without writing a yum history entry, causing incorrect reporting
- Very early support for windows added into the facts, windows tasks are coming soon!

## Release 0.3.5

- Bugfixes for the timeout code, specifically affected earlier versions of RHEL
- Fix for the 'needs reboot' variances across OS versions
- stdout buffering fix for RHEL6
- Doco updates
- Many rubocop fixes

## Release 0.3.4

- Got rid of a lot of the old hacky shell code from the scripts
- Improved the output of the packages affected by patching on yum based systems
- Lots of doco and example updates

## Release 0.3.3

- Ensure we honour reboot_override even if the OS says a reboot isn't required

## Release 0.3.2

- Fix data validation issue with yum_params and dpkg_params

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

