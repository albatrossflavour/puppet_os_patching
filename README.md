# os_patching

This module contains a set of tasks and custom facts to allow the automation of and reporting on operating system patching, currently restricted to Redhat derivitives.

## Table of contents

- [os_patching](#ospatching)
  - [Table of contents](#table-of-contents)
  - [Description](#description)
  - [Setup](#setup)
    - [What os_patching affects](#what-ospatching-affects)
    - [Beginning with os_patching](#beginning-with-ospatching)
  - [Usage](#usage)
  - [Reference](#reference)
  - [Limitations](#limitations)
  - [Development](#development)
  - [Contributors](#contributors)

## Description

Puppet tasks and bolt have opened up methods to integrate operating system level patching into the pupept workflow.  Providing automation of patch execution through tasks and the robust reporting of state through custom facts and PuppetDB.

If you're looking for a simple way to report on your OS patch levels, this module will show all updates which are outstanding, including which are related to security updates.  Do you want to enable self-service patching?  This module will use Puppet's RBAC and orchestration facilities to give you that power.

## Setup

### What os_patching affects

The module, when added to a node, creates a directory to cache patch data, installs a script to generate the cache and a cron job to run the script.  It also installs a dynamic custom fact which reports on the patching state of the server.

### Beginning with os_patching

Once the module has been installed, using either the Puppetfile or manually, it will start to collect facts and provide access to the tasks needed to patch servers.

## Usage

```puppet
include os_patching
```

## Reference

Not yet documented **TODO**

## Limitations

This module is for PE2018+ with agents capable of running tasks.  It is currently limited to the Red Hat operating system.

## Development

Fork, develop, submit a pull request

## Contributors

- Tony Green <tgreen@albatrossflavour.com>
