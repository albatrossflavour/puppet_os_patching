# @summary This manifest sets up the script and cron job to write
#   custom structured facts that contain patching data.
# @example include os_patching
class os_patching (
  String $patch_data_owner      = 'root',
  String $patch_data_group      = 'root',
  String $patch_cron_user       = $patch_data_owner,
  Boolean $install_delta_rpm    = false,
  $patch_cron_hour              = absent,
  $patch_cron_month             = absent,
  $patch_cron_monthday          = absent,
  $patch_cron_weekday           = absent,
  $patch_cron_min               = fqdn_rand(59),
){
  $fact_cmd = '/usr/local/bin/os_patching_fact_generation.sh'

  if ( $::kernel != 'Linux' ) { fail('Unsupported OS') }

  if ( $::osfamily == 'RedHat' ) {
    package { 'deltarpm':
      ensure => $install_delta_rpm,
    }
  }

  file { $fact_cmd:
    ensure => present,
    owner  => $patch_data_owner,
    group  => $patch_data_group,
    mode   => '0700',
    source => "puppet:///modules/${module_name}/os_patching_fact_generation.sh",
    notify => Exec[$fact_cmd],
  }

  exec { $fact_cmd:
    user        => $patch_data_owner,
    group       => $patch_data_group,
    refreshonly => true,
    require     => File[$fact_cmd],
  }

  cron { 'Cache patching data':
    ensure   => present,
    command  => $fact_cmd,
    user     => $patch_cron_user,
    hour     => $patch_cron_hour,
    minute   => $patch_cron_min,
    month    => $patch_cron_month,
    monthday => $patch_cron_monthday,
    weekday  => $patch_cron_weekday,
    require  => File[$fact_cmd],
  }
}
