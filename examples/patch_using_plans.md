# Patching with plans

You can use bolt plans to add conditional logic into patching.  An example plan can be found in the `plans` directory of the module.

`bolt plan run --modulepath=~/.puppetlabs/bolt/modules os_patching::patch_after_healthcheck -n ssh://centos7.example.com --no-host-key-check --run-as root`


```
Starting: plan os_patching::patch_after_healthcheck
Starting: task puppet_health_check::agent_health on ssh://centos7.example.com, ssh://puppetmaster.example.com
Finished: task puppet_health_check::agent_health with 0 failures in 2.78 sec
Skipping the following nodes due to health check failures : [{"node":"ssh://puppetmaster.example.com","type":"task","object":"puppet_health_check::agent_health","status":"success","result":{"issues":{"noop":"noop set to true should be false"},"state":"issues found","certname":"puppetmaster.example.com","date":"2019-04-26T14:28:28+10:00","noop_run":false}}]
Starting: task os_patching::patch_server on centos7.example.com
Finished: task os_patching::patch_server with 0 failures in 12.33 sec
Finished: plan os_patching::patch_after_healthcheck in 15.14 sec
Finished on centos7.example.com:
  {
    "return": "Success",
    "reboot": "never",
    "security": false,
    "message": "No patches to apply",
    "packages_updated": "",
    "debug": "",
    "job_id": "",
    "pinned_packages": [

    ],
    "start_time": "2019-04-26T14:28:29+10:00",
    "end_time": "2019-04-26T14:28:41+10:00"
  }
Successful on 1 node: centos7.example.com
Ran on 1 node
```

