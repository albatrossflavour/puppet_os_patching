# Getting the app restart required status

You can use the puppet facts to query the app restart required status on your nodes.


```bash
puppet-task run facter_task fact=os_patching -q 'nodes[certname] { }' --format json  | jq '.items[] | {node: .name, apps_needing_restart: .results.os_patching.reboots.apps_needing_restart}'
```

The output will look like this:
```json
{
  "node": "puppetmaster.example.com",
  "apps_needing_restart": {
    "630": "/usr/sbin/NetworkManager --no-daemon ",
    "1232": "/usr/bin/python -Es /usr/sbin/tuned -l -P ",
    "1451": "/usr/bin/python2 -s /usr/bin/fail2ban-server -s /var/run/fail2ban/fail2ban.sock -p /var/run/fail2ban/fail2ban.pid -x -b "
  }
}
{
  "node": "centos.example.com",
  "apps_needing_restart": {}
}
```
