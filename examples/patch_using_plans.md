# Patching with plans

You can use bolt plans to add conditional logic into patching.  An example plan can be found in the `plans` directory of the module.

`bolt plan run --modulepath=~/.puppetlabs/bolt/modules os_patching::patch_after_healthcheck -n ssh://centos7.example.com --no-host-key-check --run-as root`
