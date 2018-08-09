# Getting patch status from nodes

You can use the puppet facts to query the patching status on your nodes.


```bash
root@puppetmaster ~ # puppet-task run facter_task fact=os_patching --nodes centos.example.com --format json  | jq '.'
```

The output will look like this:
```json
{
  "job_id": "308",
  "command": "task",
  "options": {
    "noop": false,
    "task": "facter_task",
    "scope": {
      "nodes": [
        "centos.example.com"
      ]
    },
    "params": {
      "fact": "os_patching"
    },
    "transport": "pxp",
    "description": "",
    "environment": "production"
  },
  "owner": "admin",
  "start_timestamp": "2018-08-08T22:26:11Z",
  "items": [
    {
      "name": "centos.example.com",
      "state": "finished",
      "results": {
        "os_patching": {
          "pinned_packages": [],
          "blackouts": {
            "Test change freeze 2": {
              "end": "2018-08-01T11:15:50+1000",
              "start": "2018-08-01T09:17:10+1000"
            }
          },
          "security_package_updates": [],
          "package_update_count": 0,
          "package_updates": [],
          "last_run": {
            "date": "2018-08-08T10:18:50+10:00",
            "job_id": null,
            "message": "No patches to apply",
            "post_reboot": "false",
            "return_code": "Success",
            "security_only": "false"
          },
          "blocked_reasons": [],
          "blocked": false,
          "security_package_update_count": 0
        }
      }
    }
  ],
  "state": "finished",
  "finish_timestamp": "2018-08-08T22:26:16Z"
}
```

To show summary info for your last run:
```bash
puppet-task run facter_task fact=os_patching -q 'nodes[certname] { }' --format json
```

You can view this in a nicer format using 'jq':
```bash
puppet-task run facter_task fact=os_patching -q 'nodes[certname] { }' --format json  | jq '.items[] | {node: .name, status: .results.os_patching.last_run.return_code, message: .results.os_patching.last_run.message, date: .results.os_patching.last_run.date}'
```

which will output:
```json
{
  "node": "localhost.localdomain",
  "status": null,
  "message": null,
  "date": null
}
{
  "node": "centos-desktop.example.com",
  "status": null,
  "message": null,
  "date": null
}
{
  "node": "puppetmaster.example.com",
  "status": "Success",
  "message": "No patches to apply",
  "date": "2018-08-08T07:53:26+10:00"
}
{
  "node": "centos.example.com",
  "status": "Success",
  "message": "No patches to apply",
  "date": "2018-08-08T10:18:50+10:00"
}
```
