# @summary This manifest sets up the script and cron job to write
#   custom structured facts that contain patching data.
# @example include os_patching
class os_patching (
  String $patch_data_bin_dir    = '/usr/local/bin',
  String $patch_data_owner      = 'root',
  String $patch_data_group      = 'root',
  String $patch_cron_user       = $patch_data_owner,
  Boolean $install_delta_rpm    = false,
  $patch_cron_hour              = '*',
  $patch_cron_min               = fqdn_rand(59),
){
  $fact_cmd =  "${patch_data_bin_dir}/os_patching_fact_generation.sh"

  package { 'deltarpm':
    ensure => $install_delta_rpm,
  }

  file { $fact_cmd:
    ensure => present,
    owner  => $patch_data_owner,
    group  => $patch_data_group,
    mode   => '0700',
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
