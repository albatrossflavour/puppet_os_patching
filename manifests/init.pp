# @summary This manifest sets up a script and cron job to populate
#   the `os_patching` fact.
#
# @param patch_data_owner [String]
#   User name for the owner of the patch data
#
# @param patch_data_group [String]
#   Group name for the owner of the patch data
#
# @param patch_cron_user [String]
#   User who runs the cron job
#
# @param manage_yum_utils [Boolean]
#   Should the yum_utils package be managed by this module on RedHat family nodes?
#   If `true`, use the parameter `yum_utils` to determine how it should be manged
#
# @param yum_utils
#   If managed, what should the yum_utils package set to?
#
# @param fact_upload [Boolean]
#   Should `puppet fact upload` be run after any changes to the fact cache files?
#
# @param manage_delta_rpm [Boolean]
#   Should the deltarpm package be managed by this module on RedHat family nodes?
#   If `true`, use the parameter `delta_rpm` to determine how it should be manged
#
# @param delta_rpm
#   If managed, what should the delta_rpm package set to?
#
# @param manage_yum_plugin_security [Boolean]
#   Should the yum_plugin_security package be managed by this module on RedHat family nodes?
#   If `true`, use the parameter `yum_plugin_security` to determine how it should be manged
#
# @param yum_plugin_security
#   If managed, what should the yum_plugin_security package set to?
#
# @param reboot_override
#   Controls on a node level if a reboot should/should not be done after patching.
#   This overrides the setting in the task
#
# @option blackout_windows [String] :title
#   Name of the blackout window
#
# @option blackout_windows [String] :start
#   Start of the blackout window (ISO8601 format)
#
# @option blackout_windows [String] :end
#   End of the blackout window (ISO8601 format)
#
# @param patch_window [String]
#   A freeform text entry used to allocate a node to a specific patch window (Optional)
#
# @param patch_cron_hour
#   The hour(s) for the cron job to run (defaults to absent, which means '*' in cron)
#
# @param patch_cron_month
#   The month(s) for the cron job to run (defaults to absent, which means '*' in cron)
#
# @param patch_cron_monthday
#   The monthday(s) for the cron job to run (defaults to absent, which means '*' in cron)
#
# @param patch_cron_weekday
#   The weekday(s) for the cron job to run (defaults to absent, which means '*' in cron)
#
# @param patch_cron_min
#   The min(s) for the cron job to run (defaults to a random number between 0 and 59)
#
# @param ensure
#   `present` to install scripts, cronjobs, files, etc, `absent` to cleanup a system that previously hosted us
#
# @example assign node to 'Week3' patching window, force a reboot and create a blackout window for the end of the year
#   class { 'os_patching':
#     patch_window     => 'Week3',
#     reboot_override  => 'always',
#     blackout_windows => { 'End of year change freeze':
#       {
#         'start': '2018-12-15T00:00:00+10:00',
#         'end': '2019-01-15T23:59:59+10:00',
#       }
#     },
#   }
#
# @example An example profile to setup patching, sourcing blackout windows from hiera
#   class profiles::soe::patching (
#     $patch_window     = undef,
#     $blackout_windows = undef,
#     $reboot_override  = undef,
#   ){
#     # Pull any blackout windows out of hiera
#     $hiera_blackout_windows = lookup('profiles::soe::patching::blackout_windows',Hash,hash,{})
#
#     # Merge the blackout windows from the parameter and hiera
#     $full_blackout_windows = $hiera_blackout_windows + $blackout_windows
#
#     # Call the os_patching class to set everything up
#     class { 'os_patching':
#       patch_window     => $patch_window,
#       reboot_override  => $reboot_override,
#       blackout_windows => $full_blackout_windows,
#     }
#   }
#
# @example JSON hash to specify a change freeze from 2018-12-15 to 2019-01-15
#   {"End of year change freeze": {"start": "2018-12-15T00:00:00+10:00", "end": "2019-01-15T23:59:59+10:00"}}
#
# @example Run patching on the node `centos.example.com` using the smart reboot option
#   puppet task run os_patching::patch_server --params '{"reboot": "smart"}' --nodes centos.example.com
#
# @example Remove from a managed system
#   class { 'os_patching':
#     ensure => absent,
#   }
class os_patching (
  String $patch_data_owner            = 'root',
  String $patch_data_group            = 'root',
  String $patch_cron_user             = $patch_data_owner,
  Boolean $manage_yum_utils           = false,
  Boolean $manage_delta_rpm           = false,
  Boolean $manage_yum_plugin_security = false,
  Boolean $fact_upload                = true,
  Enum['installed', 'absent', 'purged', 'held', 'latest'] $yum_utils = 'installed',
  Enum['installed', 'absent', 'purged', 'held', 'latest'] $delta_rpm = 'installed',
  Enum['installed', 'absent', 'purged', 'held', 'latest'] $yum_plugin_security = 'installed',
  Optional[Variant[Boolean, Enum['always', 'never', 'patched', 'smart', 'default']]] $reboot_override = 'default',
  Optional[Hash] $blackout_windows   = undef,
  $patch_window                      = undef,
  $patch_cron_hour                   = absent,
  $patch_cron_month                  = absent,
  $patch_cron_monthday               = absent,
  $patch_cron_weekday                = absent,
  $patch_cron_min                    = fqdn_rand(59),
  Enum['present', 'absent'] $ensure  = 'present',
) {

  case $facts['kernel'] {
    'windows': {
      $cache_dir = 'C:\ProgramData\os_patching'
      $fact_cmd = 'os_patching_fact_generation.ps1'
      $fact_dir = $cache_dir
      $fact_upload_cmd = 'C:\Program Files\Puppet Labs\Puppet\bin\puppet facts upload'
      $fact_path = "${fact_dir}\${fact_cmd}"
      File [
        owner => 'Administrator',
      ]
    }
    'linux': {
      $cache_dir = '/var/cache/os_patching'
      $fact_cmd = 'os_patching_fact_generation.sh'
      $fact_dir = '/usr/local/bin'
      $fact_upload_cmd = '/opt/puppetlabs/bin/puppet facts upload'
      $fact_path = "${fact_dir}/${fact_cmd}"
      File [
        owner => 'root',
        group => 'root',
        mode  => '0644',
      ]
    }
    default: { fail(translate('Unsupported OS')) }
  }

  $fact_exec = $ensure ? {
    'present' => 'os_patching::exec::fact',
    default   => undef,
  }

  $fact_upload_exec = $ensure ? {
    'present' => 'os_patching::exec::fact_upload',
    default   => undef
  }

  $ensure_file = $ensure ? {
    'present' => 'file',
    default   => 'absent',
  }

  $ensure_dir = $ensure ? {
    'present' => 'directory',
    default   => 'absent',
  }

  if ($patch_window and $patch_window !~ /[A-Za-z0-9\-_ ]+/ ) {
    fail(translate('The patch window can only contain alphanumerics, space, underscore and dash'))
  }

  if ( $facts['os']['family'] == 'RedHat' and $manage_yum_utils) {
    package { 'yum-utils':
      ensure => $yum_utils,
    }
  }

  if ( $facts['os']['family'] == 'RedHat' and $manage_delta_rpm) {
    package { 'deltarpm':
      ensure => $delta_rpm,
    }
  }

  if ( $facts['os']['family'] == 'RedHat' and $manage_yum_plugin_security) {
    package { 'yum-plugin-security':
      ensure => $yum_plugin_security,
    }
  }

  file { $cache_dir:
    ensure => $ensure_dir,
    force  => true,
  }

  file { $fact_path:
    ensure => $ensure_file,
    owner  => $patch_data_owner,
    group  => $patch_data_group,
    mode   => '0700',
    source => "puppet:///modules/${module_name}/${fact_cmd}",
    notify => Exec[$fact_exec],
  }

  if $fact_exec {
    exec { $fact_exec:
      command     => $fact_path,
      user        => $patch_data_owner,
      group       => $patch_data_group,
      refreshonly => true,
      require     => File[$fact_cmd],
    }
  }

  if $facts['kernel'] == 'Linux' {
    cron { 'Cache patching data':
      ensure   => $ensure,
      command  => $fact_cmd,
      user     => $patch_cron_user,
      hour     => $patch_cron_hour,
      minute   => $patch_cron_min,
      month    => $patch_cron_month,
      monthday => $patch_cron_monthday,
      weekday  => $patch_cron_weekday,
      require  => File[$fact_cmd],
    }

    cron { 'Cache patching data at reboot':
      ensure  => $ensure,
      command => $fact_cmd,
      user    => $patch_cron_user,
      special => 'reboot',
      require => File[$fact_cmd],
    }
  }

  $patch_window_ensure = ($ensure == 'present' and $patch_window ) ? {
    true    => 'file',
    default => 'absent'
  }

  file { "${cache_dir}/patch_window":
    ensure  => $patch_window_ensure,
    content => $patch_window,
  }

  $reboot_override_ensure = ($ensure == 'present' and $reboot_override) ? {
    true    => 'file',
    default => 'absent',
  }

  case $reboot_override {
    true: { $reboot_override_value = 'always' }
    false: { $reboot_override_value = 'never' }
    default: { $reboot_override_value = $reboot_override }
  }

  file { "${cache_dir}/reboot_override":
    ensure  => $reboot_override_ensure,
    content => $reboot_override_value,
  }


  if ($blackout_windows) {
    # Validate the information in the blackout_windows hash
    $blackout_windows.each | String $key, Hash $value | {
      if ( $key !~ /^[A-Za-z0-9\-_ ]+$/ ){
        fail translate(('Blackout description can only contain alphanumerics, space, dash and underscore'))
      }
      if ( $value['start'] !~ /^\d{,4}-\d{1,2}-\d{1,2}T\d{,2}:\d{,2}:\d{,2}[-\+]\d{,2}:\d{,2}$/ ){
        fail translate(('Blackout start time must be in ISO 8601 format (YYYY-MM-DDTdd:mm:hh:ss[-+]hh:mm)'))
      }
      if ( $value['end'] !~ /^\d{,4}-\d{1,2}-\d{1,2}T\d{,2}:\d{,2}:\d{,2}[-\+]\d{,2}:\d{,2}$/ ){
        fail translate(('Blackout end time must be in ISO 8601 format  (YYYY-MM-DDTdd:mm:hh:ss[-+]hh:mm)'))
      }
      if ( $value['start'] > $value['end'] ){
        fail translate(('Blackout end time must after the start time'))
      }
    }
  }
  $blackout_windows_ensure = ($ensure == 'present' and $blackout_windows) ? {
    true    => 'file',
    default => 'absent'
  }

  file { "${cache_dir}/blackout_windows":
    ensure  => $blackout_windows_ensure,
    content => epp("${module_name}/blackout_windows.epp", {
      'blackout_windows' => pick($blackout_windows, {}),
    }),
    require => File[$cache_dir],
  }

  if $fact_upload_exec and $fact_upload {
    exec { $fact_upload_exec:
      command     => $fact_upload_cmd,
      path        => ['/usr/bin','/bin','/sbin','/usr/local/bin'],
      refreshonly => true,
      subscribe   => File[
        $fact_path,
        $cache_dir,
        "${cache_dir}/patch_window",
        "${cache_dir}/reboot_override",
        "${cache_dir}/blackout_windows",
      ],
    }
  }
}
