### Show all patch windows

```
puppet=query 'fact_contents[value, count()] { path = ["os_patching", "patch_window"] group by value }'
```

### Show nodes with available updates

```
puppet-query 'inventory[certname] { facts.os_patching.package_update_count > 0 }'
```

### Show nodes pending a reboot

```
puppet-query 'inventory[certname] { facts.os_patching.reboots.reboot_required = true }'
```
