# Patch nodes and capture live json output

If you want to patch using a script which will parse the results, you can do something similar to this:

```bash
puppet task run os_patching::patch_server --query='nodes[certname] { }' --format json | jq '.'
```

This will give you a full task report, with status per node and an overall status at the end:
```json
{
  "job_id": "335",
  "command": "task",
  "options": {
    "noop": false,
    "task": "os_patching::patch_server",
    "scope": {
      "query": "nodes[certname] { }"
    },
    "params": {},
    "transport": "pxp",
    "description": "",
    "environment": "production"
  },
  "owner": "admin",
  "start_timestamp": "2018-08-08T22:57:44Z",
  "items": [
    {
      "name": "localhost.localdomain",
      "state": "errored",
      "results": {
        "_error": {
          "msg": "localhost.localdomain is not connected to the PCP broker",
          "kind": "puppetlabs.orchestrator/execution-failure",
          "details": {
            "node": "localhost.localdomain"
          }
        }
      }
    },
    {
      "name": "linode-centos-73.bandcamp.tv",
      "state": "finished",
      "results": {
        "pinned_packages": [],
        "security": false,
        "return": "Success",
        "start_time": "2018-08-09T08:57:44+10:00",
        "debug": "",
        "end_time": "2018-08-09T08:58:00+10:00",
        "reboot": false,
        "packages_updated": "",
        "job_id": "",
        "message": "No patches to apply"
      }
    },
    {
      "name": "puppetmaster.bandcamp.tv",
      "state": "failed",
      "results": {
        "_error": {
          "msg": "Task exited : 100\nPatching blocked ",
          "kind": "os_patching/blocked",
          "details": {
            "exitcode": "100"
          },
          "end_time": "2018-08-09T08:58:03+10:00",
          "start_time": "2018-08-09T08:57:44+10:00"
        }
      }
    }
  ],
  "state": "failed",
  "finish_timestamp": "2018-08-08T22:58:03Z"
}
```
