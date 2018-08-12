# Patch nodes and capture live json output

## Selecting the nodes to patch
You can use the query parameter to `puppet task` to determine which nodes you wish to act upon.  The easiest example of this is to limit the patching to just nodes assigned to the 'Week3' patch window.:

```bash
puppet task run os_patching::patch_server --query='nodes[certname] { facts.os_patching.patch_window = "Week3" }'
```

More details on using queries within tasks can [be found on Puppet's website](https://puppet.com/docs/pe/2018.1/running_tasks_from_the_command_line.html#task-8683)

## Capturing and parsing resuls
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
      "name": "centos.example.com",
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
      "name": "puppetmaster.example.com",
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
