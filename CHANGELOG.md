# Changelog

## Release 0.7.1 (2018-12-10)

- Bugfix on the filter code

## Release 0.7.0 (2018-12-10)

- New task to force the fact cache to refresh
- Some filters for potentially dodgy yum output during fact caching
- Confine the fact to only run on Windows and Linux

## Release 0.6.4 (2018-10-03)

- Fix debian cache cleaning command

## Release 0.6.3 (2018-10-03)

- Fix debian nodes not showing the reboot_required fact if one is required

## Release 0.6.2 (2018-10-03)

- Reenable security only patching on debian based systems

## Release 0.6.1 (2018-10-03)

- Fix a couple of puppet strings issues

## Release 0.6.0 (2018-10-03)

- [PDQtest](https://github.com/declarativesystems/pdqtest)ing a-go-go, lots of acceptance testing
- Moved default UNIX cache directory to `/var/cache/os_patching`.  Should be transparent other than losing the history file.  History information still available from syslog and/or package commands
- Improved reporting and error checking
- Fixed documentation issues
- Switch to epp template for blackout windows
- New `clean_cache` task to flush the OS package cache on RedHat/Debian
- New `clean_cache` parameter to the os_patching task
- Did I mention the acceptance tests?
- New paramters for the `reboot` parameter
- Unify the arguments between the task parameter `reboot` and the `reboot_override` fact - see the documentation for more details
- Improve the way we handle managing RPMs we depend on (see `manage_*` in the manifest)
- Also, acceptance testing
- Move to new PDK template

## Release 0.5.0 (2018-09-24)

- Rewrite of the reboot logic for both the task and the `reboot_override` fact.  **SHOULD** be backward compatable with how things used to work but it's now much cleaner and clearer.
- Updated logging, documentation and comments

## Release 0.4.1 (2018-09-16)

- Missed some metadata info updates in 0.4.0

## Release 0.4.0 (2018-09-16)

- Some [issues](https://github.com/albatrossflavour/puppet_os_patching/issues/36) found with the use of needs-restarting on RHEL6 based systems under certain circumstances.  Updated the tasks and facts to cope with it.
- Ensure lock file is cleaned up if the os_patching_fact_generation.sh script is interupted or killed.
- Fix the regex matching for packages that start with a numeric or a capital letter
- Add a new 'warning' entry in the os_patching fact to allow highlighting of potential issues (cache files not updated in a while or not present)
- Catch times when yum would exit without writing a yum history entry, causing incorrect reporting
- Very early support for windows added into the facts, windows tasks are coming soon!

## Release 0.3.5 (2018-08-16)

- Bugfixes for the timeout code, specifically affected earlier versions of RHEL
- Fix for the 'needs reboot' variances across OS versions
- stdout buffering fix for RHEL6
- Doco updates
- Many rubocop fixes

## Release 0.3.4 (2018-08-10)

- Got rid of a lot of the old hacky shell code from the scripts
- Improved the output of the packages affected by patching on yum based systems
- Lots of doco and example updates

## Release 0.3.3 (2018-08-09)

- Ensure we honour reboot_override even if the OS says a reboot isn't required

## Release 0.3.2 (2018-08-09)

- Fix data validation issue with yum_params and dpkg_params

## Release 0.3.1 (2018-08-09)

- A new fact (reboots) is available.
  - reboots.reboot_required shows if the OS belives it needs to be restarted
  - app_restart_required shows if the OS can detect and processes using previously patched files
  - apps_needing_restart is a hash of the PID and command line of those processes
- Reboots integrated into patching task
- Documentation and examples updated

## Release 0.2.1 (2018-08-08)

- Major rewrite on most areas of the module
- Patching task now written in ruby and has much better reporting and error handling
- Facter is now ruby based but still uses cache data from a cron job
- Blackout window functionality included
- Documentation updates
- SHOULD be backwards compatible

## Release 0.1.19 (2018-07-09)

- Bugfix on the debian task which caused incorrect reporting of patching status

## Release 0.1.18 (2018-06-21)

- Many improvements in the debian workflow
- Pull out information for pinned/version locked/held packages
- Removed redundant task
- Cleaner patch fact generation

## Release 0.1.17 (2018-06-01)

- Added initial support for Debian/Ubuntu systems

## Release 0.1.16 (2018-05-30)

- Additional logging, through `logger`, on both fact generation and patching
- Clean up of the puppet manifest
- Add all of the cron schedule options as parameters
- Add security update reporting (requires a RHEL subscription)
- Automatically re-run the fact script during the puppet run if it changes

## Release 0.1.15 (2018-05-28)

- Rewrite of patch facts and tasks

