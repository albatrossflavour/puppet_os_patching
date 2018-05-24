class os_patching (
  $patch_data_bin_dir    = '/usr/local/bin',
  $patch_data_cache_dir  = '/var/patching-data',
  $patch_data_owner      = 'root',
  $patch_data_group      = 'root',
  $patch_required_pkgs   = [ 'yum', 'rpm' ],
){

  $cache_cmd =  "${patch_data_bin_dir}/generate_patch_cache"

  packge { $patch_required_pkgs:
    ensure => present,
  }

  file { $patch_data_cache_dir:
    ensure  => directory,
    uid     => $patch_data_owner,
    gid     => $patch_data_group,
    mode    => '0700'
    require => $patch_required_pkgs,
  }

  file { $cache_cmd:
    ensure  => present,
    uid     => $patch_data_owner
    gid     => $patch_data_group,
    mode    => '0700',
    content => template('profiles/os_patching/generate_patch_cache.erb')
  }

  cron { 'Cache patching data':
    ensure  => present,
    command => $cache_cmd,
    user    => 'root',
    hour    => '*',
    minute  => fqdn_rand(59),
    require => File($cache_cmd)
  }
}
