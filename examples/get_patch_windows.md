# Get patch windows

To see all assigned patch windows:

```bash
puppet-task run facter_task fact=os_patching -q 'nodes[certname] { }' --format json  | jq '.items[] | {node: .name, patch_window: .results.os_patching.patch_window, blocked: .results.os_patching.blocked}'
```

```json
{
  "node": "centos.example.com",
  "patch_window": null,
  "blocked": false
}
{
  "node": "puppetmaster.example.com",
  "patch_window": "42",
  "blocked": true
}
```

To see all nodes from a specific patch window ('42' in this example):
```bash
puppet-task run facter_task fact=os_patching -q 'inventory[certname] { facts.os_patching.patch_window = "42" }' --format json  | jq '.items[] | {node: .name, patch_window: .results.os_patching.patch_window, blocked: .results.os_patching.blocked}'
```

```json
{
  "node": "puppetmaster.example.com",
  "patch_window": "42",
  "blocked": true
}


To see all nodes without an assigned patch window:
```bash
puppet-task run facter_task fact=os_patching -q 'inventory[certname] { facts.os_patching.patch_window is null }' --format json  | jq '.items[] | {node: .name, patch_window: .results.os_patching.patch_window, blocked: .results.os_patching.blocked}'
```

```json
{
  "node": "centos.example.com",
  "patch_window": null,
  "blocked": false
}
```
