# Blackout windows and blockers

To see what blackout windows are in effect on a node and if it's currently blocked from patching, you can use:
```bash
$ puppet-task run facter_task fact=os_patching --nodes centos.example.com --format json  | jq '.items[] | {node: .name, blackouts: .results.os_patching.blackouts, blocked: .results.os_patching.blocked}'
```

Will give you output like this:
```json
{
  "node": "centos.example.com",
  "blackouts": {
    "Test change freeze 2": {
      "end": "2018-08-01T11:15:50+1000",
      "start": "2018-08-01T09:17:10+1000"
    }
  },
  "blocked": false
}
```
