# rhel_patching
This module contains a set of tasks and custom facts to allow the automation of and reporting on operating system patching, currently restricted to Redhat derivitives.

#### Table of Contents

## Description

Puppet tasks and bolt have opened up methods to integrate operating system level patching into the pupept workflow.  Providing automation of patch execution through tasks and the robust reporting of state through custom facts and PuppetDB.

If you're looking for a simple way to report on your OS patch levels, this module will show all updates which are outstanding, including which are related to security updates.  Do you want to enable self-service patching?  This module will use Puppet's RBAC and orchestration facilities to give you that power.

## Setup

### What rhel_patching affects

The module will not impact the nodes and does not have to be included in any profiles.  It simply provides facts and tasks to assist in the patching and maintenance of the server.

### Beginning with rhel_patching

Once the module has been installed, using either the Puppetfile or manually, it will start to collect facts and provide access to the tasks needed to patch servers.

## Usage

**TODO**

## Reference

Users need a complete list of your module's classes, types, defined types providers, facts, and functions, along with the parameters for each. You can provide this list either via Puppet Strings code comments or as a complete list in the README Reference section.

* If you are using Puppet Strings code comments, this Reference section should include Strings information so that your users know how to access your documentation.

* If you are not using Puppet Strings, include a list of all of your classes, defined types, and so on, along with their parameters. Each element in this listing should include:

  * The data type, if applicable.
  * A description of what the element does.
  * Valid values, if the data type doesn't make it obvious.
  * Default value, if any.

## Limitations

This module is for PE2018+ with agents capable of running tasks.  It is currently limited to the Red Hat operating system.

## Development

Fork, develop, submit a pull request

## Contributors

* Tony Green <tgreen@albatrossflavour.com>