# @summary We'll get to the doco soon
 
class os_patching (
  $patch_data_bin_dir    = '/usr/local/bin',
  $patch_data_owner      = 'root',
  $patch_data_group      = 'root',
  $patch_cron_hour       = '*',
  $patch_cron_min        = fqdn_rand(59),
  $patch_cron_user       = $patch_data_owner,
  $install_delta_rpm     = false,
){
  $fact_cmd =  "${patch_data_bin_dir}/os_patching_fact_generation.sh"

  package { 'deltarpm':
    ensure => $install_delta_rpm,
  }

  File {
    owner   => $patch_data_owner,
    group   => $patch_data_group,
    mode    => '0700',
  }

  file { $fact_cmd:
    ensure => present,
    source => "puppet:///modules/${module_name}/os_patching_fact_generation.sh",
  }

  cron { 'Cache patching data':
    ensure  => present,
    command => $fact_cmd,
    user    => $patch_cron_user,
    hour    => $patch_cron_hour,
    minute  => $patch_cron_min,
    require => File[$fact_cmd],
  }
}
