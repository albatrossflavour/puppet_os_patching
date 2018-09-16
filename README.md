[![Build Status](https://travis-ci.org/albatrossflavour/puppet_os_patching.svg?branch=master)](https://travis-ci.org/albatrossflavour/puppet_os_patching)
# os_patching

This module contains a set of tasks and custom facts to allow the automation of and reporting on operating system patching, currently restricted to Redhat and Debian derivatives.

Under the hood it uses the OS level tools to carry out the actual patching.

## Description

Puppet tasks and bolt have opened up methods to integrate operating system level patching into the puppet workflow.  Providing automation of patch execution through tasks and the robust reporting of state through custom facts and PuppetDB.

If you're looking for a simple way to report on your OS patch levels, this module will show all updates which are outstanding, including which are related to security updates.  Do you want to enable self-service patching?  This module will use Puppet's RBAC and orchestration and task execution facilities to give you that power.

It also uses security metadata (where available) to determine if there are security updates.  On Redhat, this is provided from Redhat as additional metadata in YUM.  On Debian, checks are done for which repo the updates are coming from.  There is a parameter to the task to only apply security updates.

Blackout windows enable the support for time based change freezes where no patching can happen.  There can be multiple windows defined and each which will automatically expire after reaching the defined end date.

## Setup

### What os_patching affects

The module provides an additional fact (`os_patching`) and has a task to allow the patching of a server.  When the `os_patching` manifest is added to a node it installs a script and cron job to generate cache data used by the `os_patching` fact.

### Beginning with os_patching

Install the module using the Puppetfile, include it on your nodes and then use the provided tasks to carry out patching.

## Usage

### Manifest
Include the module:
```puppet
include os_patching
```

More advanced usage:
```puppet
class { 'os_patching':
  patch_window     => 'Week3',
  reboot_override  => true,
  blackout_windows => { 'End of year change freeze':
    {
      'start': '2018-12-15T00:00:00+1000',
      'end': '2019-01-15T23:59:59+1000',
    }
  },
}
```

In that example, the node is assigned to a "patch window", will be forced to reboot regardless of the setting specified in the task and has a blackout window defined for the period of 2018-12-15 - 2019-01-15, during which time no patching through the task can be carried out.

### Task
Run a basic patching task from the command line:
```bash
os_patching::patch_server - Carry out OS patching on the server, optionally including a reboot and/or only applying security related updates

USAGE:
$ puppet task run os_patching::patch_server [dpkg_params=<value>] [reboot=<value>] [security_only=<value>] [timeout=<value>] [yum_params=<value>] <[--nodes, -n <node-names>] | [--query, -q <'query'>]>

PARAMETERS:
- dpkg_params : Optional[String]
    Any additional parameters to include in the dpkg command
- reboot : Optional[Boolean]
    Should the server reboot after patching has been applied? (Defaults to false)
- security_only : Optional[Boolean]
    Limit patches to those tagged as security related? (Defaults to false)
- timeout : Optional[Integer]
    How many seconds should we wait until timing out the patch run? (Defaults to 3600 seconds)
- yum_params : Optional[String]
    Any additional parameters to include in the yum upgrade command (such as including/excluding repos)
```

Example:
```bash
$ puppet task run os_patching::patch_server --params='{"reboot": true, "security_only": false}' --query="inventory[certname] { facts.os_patching.patch_window = 'Week3' and facts.os_patching.blocked = false and facts.os_patching.package_update_count > 0}"
```

This will run a patching task against all nodes which have facts matching:

* `os_patching.patch_window` of 'Week3'
* `os_patching.blocked` equals `false`
* `os_patching.package_update_count` greater than 0

The task will apply all patches (`security_only=false`) and will reboot the node after patching (`reboot=true`).

## Reference

### Facts

Most of the reporting is driven off the custom fact `os_patching_data`, for example:

```yaml
# facter -p os_patching
{
  package_update_count => 0,
  package_updates => [],
  security_package_updates => [],
  security_package_update_count => 0,
  blocked => false,
  blocked_reasons => [],
  blackouts => {},
  patch_window = 'Week3',
  pinned_packages => [],
  last_run => {
    date => "2018-08-07T21:55:20+10:00",
    message => "Patching complete",
    return_code => "Success",
    post_reboot => "false",
    security_only => "false",
    job_id => "60"
  }
  reboots => {
    reboot_required => false,
    apps_needing_restart => { },
    app_restart_required => false
  }
}
```

This shows there are no updates which can be applied to this server and the server doesn't need a reboot or any application restarts.  When there are updates to add, you will see similar to this:

```yaml
# facter -p os_patching
{
  package_update_count => 6,
  package_updates => [
    "kernel.x86_64",
    "kernel-tools.x86_64",
    "kernel-tools-libs.x86_64",
    "postfix.x86_64",
    "procps-ng.x86_64",
    "python-perf.x86_64"
  ]
  security_package_updates => [],
  security_package_update_count => 0,
  blocked => false,
  blocked_reasons => [],
  blackouts => {
    Test change freeze 2 => {
      start => "2018-08-01T09:17:10+1000",
      end => "2018-08-01T11:15:50+1000"
    }
  },
  pinned_packages => [],
  patch_window = 'Week3',
  last_run => {
    date => "2018-08-07T21:55:20+10:00",
    message => "Patching complete",
    return_code => "Success",
    post_reboot => "false",
    security_only => "false",
    job_id => "60"
  }
  reboots => {
    reboot_required => true,
    apps_needing_restart => {
      630 => "/usr/sbin/NetworkManager --no-daemon ",
      1451 => "/usr/bin/python2 -s /usr/bin/fail2ban-server -s /var/run/fail2ban/fail2ban.sock -p /var/run/fail2ban/fail2ban.pid -x -b ",
      1232 => "/usr/bin/python -Es /usr/sbin/tuned -l -P "
    },
    app_restart_required => true
  }
}
```

Where it shows 6 packages with available updates, along with an array of the package names.  None of the packges are tagged as security related (requires Debian or a subscription to RHEL).  There are no blockers to patching and the blackout window defined is not in effect.

The reboot_required flag is set to true, which means there have been changes to packages that require a reboot (libc, kernel etc) but a reboot hasn't happened.  The apps_needing_restart shows the PID and command line of applications that are using files that have been upgraded but the process hasn't been restarted.

The pinned packages entry lists any packages which have been specifically excluded from being patched, from [version lock](https://access.redhat.com/solutions/98873) on Red Hat or by [pinning](https://wiki.debian.org/AptPreferences) in Debian.

Last run shows a summary of the information from the last `os_patching::patch_server` task.

The fact `os_patching.patch_window` can be used to assign nodes to an arbitrary group.  The fact can be used as part of the query fed into the task to determine which nodes to patch:

```bash
$ puppet task run os_patching::patch_server --query="inventory[certname] {facts.os_patching.patch_window = 'Week3'}"
```

### Task output

If there is nothing to be done, the task will report:

```json
{
  "pinned_packages" : [ ],
  "security" : false,
  "return" : "Success",
  "start_time" : "2018-08-08T07:52:28+10:00",
  "debug" : "",
  "end_time" : "2018-08-08T07:52:46+10:00",
  "reboot" : false,
  "packages_updated" : "",
  "job_id" : "",
  "message" : "No patches to apply"
}
```

If patching was executed, the task will report similar to below:

```json
{
  "pinned_packages" : [ ],
  "security" : false,
  "return" : "Success",
  "start_time" : "2018-08-07T21:55:20+10:00",
  "debug" : "TRIMMED DUE TO LENGTH FOR THIS EXAMPLE, WOULD NORMALLY CONTAIN FULL COMMAND OUTPUT",
  "end_time" : "2018-08-07T21:57:11+10:00",
  "reboot" : false,
  "packages_updated" : [ "NetworkManager-1:1.10.2-14.el7_5.x86_64", "NetworkManager-libnm-1:1.10.2-14.el7_5.x86_64", "NetworkManager-team-1:1.10.2-14.el7_5.x86_64", "NetworkManager-tui-1:1.10.2-14.el7_5.x86_64", "binutils-2.27-27.base.el7.x86_64", "centos-release-7-5.1804.el7.centos.2.x86_64", "git-1.8.3.1-13.el7.x86_64", "gnupg2-2.0.22-4.el7.x86_64", "kernel-tools-3.10.0-862.3.3.el7.x86_64", "kernel-tools-libs-3.10.0-862.3.3.el7.x86_64", "perl-Git-1.8.3.1-13.el7.noarch", "python-2.7.5-68.el7.x86_64", "python-libs-2.7.5-68.el7.x86_64", "python-perf-3.10.0-862.3.3.el7.centos.plus.x86_64", "selinux-policy-3.13.1-192.el7_5.3.noarch", "selinux-policy-targeted-3.13.1-192.el7_5.3.noarch", "sudo-1.8.19p2-13.el7.x86_64", "yum-plugin-fastestmirror-1.1.31-45.el7.noarch", "yum-utils-1.1.31-45.el7.noarch" ],
  "job_id" : "60",
  "message" : "Patching complete"
}
```

If patching was blocked, the task will report similar to below:

```json
Error: Task exited : 100
Patching blocked
```
A summary of the patch run is also written to `/etc/os_patching/run_history`, the last line of which is used by the `os_patching.last_run` fact.

```bash
2018-08-07T14:47:24+10:00|No patches to apply|Success|false|false|
2018-08-07T14:56:56+10:00|Patching complete|Success|false|false|121
2018-08-07T15:04:42+10:00|yum timeout after 2 seconds : Loaded plugins: versionlock|1|||
2018-08-07T15:05:51+10:00|yum timeout after 3 seconds : Loaded plugins: versionlock|1|||
2018-08-07T15:10:16+10:00|Patching complete|Success|false|false|127
2018-08-07T21:31:47+10:00|Patching blocked |100|||
2018-08-08T07:53:59+10:00|Patching blocked |100|||
```

### `/etc/os_patching` directory

This directory contains the various control files needed for the fact and task to work correctly.  They are managed by the manifest.

* `/etc/os_patching/blackout_windows` : contains name, start and end time for all blackout windows
* `/etc/os_patching/package_updates` : a list of all package updates available, populated by `/usr/local/bin/os_patching_fact_generation.sh`, triggered through cron
* `/etc/os_patching/security_package_updates` : a list of all security_package updates available, populated by `/usr/local/bin/os_patching_fact_generation.sh`, triggered through cron
* `/etc/os_patching/run_history` : a summary of each run of the `os_patching::patch_server` task, populated by the task
* `/etc/os_patching/reboot_override` : if present, overrides the `reboot=` parameter to the task
* `/etc/os_patching/patch_window` : if present, sets the value for the fact `os_patching.patch_window`
* `/etc/os_patching/reboot_required` : if the OS can determine that the server needs to be rebooted due to package changes, this file contains the result.  Populates the fact reboot.reboot_required.
* `/etc/os_patching/apps_to_restart` : a list of processes (PID and command line) that haven't been restarted since the packages they use were patched.  Sets the fact reboot.apps_needing_restart and .reboot.app_restart_required.

With the exception of the run_history file, all files in /etc/os_patching will be regenerated after a puppet run and a run of the os_patching_fact_generation.sh script, which runs every hour by default.  If run_history is removed, the same information can be obtained from PDB, apt/yum and syslog.

## Limitations

This module is for PE2018+ with agents capable of running tasks.  It is currently limited to the Red Hat and Debian based operating systems (CentOS, Ubuntu, Debian, RedHat etc).  Windows (WSUS) functionality is being actively worked on.

Debian based systems currently do not allow `security_only` patch tasks to be set to `true`, a fix for this is being worked on.

RedHat 5 based systems have support but lack a lot of the yum functionality added in 6, so things like the upgraded package list and job ID will be missing.

## Development

Fork, develop, submit a pull request

## Contributors

- [Tony Green](tgreen@albatrossflavour.com)
    - [@albatrossflavor](https://twitter.com/albatrossflavor)
    - [http://albatrossflavour.com](http://albatrossflavour.com)
- [Brett Gray](https://github.com/beergeek)
- [Rob Nelson](https://github.com/rnelson0)
- [Tommy McNeely](https://github.com/tjm)
