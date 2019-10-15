# Pre_patching_commands

Adding the pre_patching_command parameter to a set of nodes will force the `os_patching::patch_server` task to run the command prior to running patching.

It will only be run if patching is allowed, so blockers etc will be honoured.

The file must exist on the node and be executable.  The module does *NOT* manage this.

You can use hiera to set the value:

```
---
os_patching::pre_patching_command: '/usr/local/bin/pre-patching-script'
```

or it can be set through classification


The script must `exit 0` if successful.  Any other return code will cause the task to fail.

