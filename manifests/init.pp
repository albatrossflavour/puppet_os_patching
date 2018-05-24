# @summary We'll get to the doco soon
# 
class os_patching (
  $patch_data_bin_dir    = '/usr/local/bin',
  $patch_data_cache_dir  = '/var/patching-data',
  $patch_data_owner      = 'root',
  $patch_data_group      = 'root',
  $patch_cron_hour       = '*',
  $patch_cron_min        = fqdn_rand(59),
  $patch_cron_user       = $patch_data_owner,
){
  $cache_cmd =  "${patch_data_bin_dir}/generate_patch_cache"

  File {
    owner   => $patch_data_owner,
    group   => $patch_data_group,
    mode    => '0700',
  }

  file { $patch_data_cache_dir:
    ensure  => directory,
    require => Package[$patch_required_pkgs],
  }

  file { $cache_cmd:
    ensure  => present,
    content => template("${module_name}/generate_patch_cache.erb"),
  }

  cron { 'Cache patching data':
    ensure  => present,
    command => $cache_cmd,
    user    => $patch_cron_user,
    hour    => $patch_cron_hour,
    minute  => $patch_cron_min,
    require => File($cache_cmd),
  }
}
