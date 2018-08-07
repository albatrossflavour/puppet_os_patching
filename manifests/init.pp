# @summary This manifest sets up the script and cron job to write
#   custom structured facts that contain patching data.
# @example include os_patching
class os_patching (
  String $patch_data_owner           = 'root',
  String $patch_data_group           = 'root',
  String $patch_cron_user            = $patch_data_owner,
  Boolean $install_delta_rpm         = false,
  Optional[Boolean] $reboot_override = undef,
  Optional[Hash] $blackout_windows   = undef,
  $patch_window                      = undef,
  $patch_cron_hour                   = absent,
  $patch_cron_month                  = absent,
  $patch_cron_monthday               = absent,
  $patch_cron_weekday                = absent,
  $patch_cron_min                    = fqdn_rand(59),
){
  $fact_cmd = '/usr/local/bin/os_patching_fact_generation.sh'
  $fact_upload ='/opt/puppetlabs/bin/puppet facts upload'

  if ( $::kernel != 'Linux' ) { fail('Unsupported OS') }

  if ( $::osfamily == 'RedHat' ) {
    package { 'deltarpm':
      ensure => $install_delta_rpm,
    }
  }

  file { '/opt/puppetlabs/facter/facts.d/os_patching.yaml':
    ensure => absent,
  }

  file { '/etc/os_patching':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
  }

  unless defined(Class['os_patching::block']) {
    file { '/etc/os_patching/block.conf':
      ensure => absent,
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


  $patch_window_file = '/etc/os_patching/patch_window'
  if ( $patch_window ) {
    if ($patch_window !~ /[A-Za-z0-9\-_ ]+/ ){
      fail ('The patch window can only contain alphanumerics, space, underscore and dash')
    }

    file { $patch_window_file:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => $patch_window,
      require => File['/etc/os_patching'],
      notify  => Exec[$fact_upload],
    }
  } else {
    file { $patch_window_file:
      ensure => absent,
      notify => Exec[$fact_upload],
    }
  }

  $reboot_override_file = '/etc/os_patching/reboot_override'
  if ( $reboot_override != undef ) {
    case $reboot_override {
      # lint:ignore:quoted_booleans
      true:  { $reboot_boolean = 'true' }
      false: { $reboot_boolean = 'false' }
      default: { fail ('reboot_override must be a boolean')}
      # lint:endignore
    }

    file { $reboot_override_file:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => $reboot_boolean,
      require => File['/etc/os_patching'],
      notify  => Exec[$fact_upload],
    }
  } else {
    file { $reboot_override_file:
      ensure => absent,
      notify => Exec[$fact_upload],
    }
  }

  $blackout_window_file = '/etc/os_patching/blackout_windows'
  if ( $blackout_windows ) {
    # Validate the information in the blackout_windows hash
    $blackout_windows.each | String $key, Hash $value | {
      if ( $key !~ /^[A-Za-z0-9\-_ ]+$/ ){
        fail ('Blackout description can only contain alphanumerics, space, dash and underscore')
      }
      if ( $value['start'] !~ /^[\d:T\-\\+]*$/ ){
        fail ('Blackout start time must be in ISO 8601 format')
      }
      if ( $value['end'] !~ /^[\d:T\-\\+]*$/ ){
        fail ('Blackout end time must be in ISO 8601 format')
      }
      if ( $value['start'] > $value['end'] ){
        fail ('Blackout end time must after the start time')
      }
    }
    file { $blackout_window_file:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template("${module_name}/blackout_windows.erb"),
      require => File['/etc/os_patching'],
      notify  => Exec[$fact_upload],
    }
  } else {
    file { $blackout_window_file:
      ensure => absent,
      notify => Exec[$fact_upload],
    }
  }

  exec { $fact_upload:
    refreshonly => true,
  }
}
