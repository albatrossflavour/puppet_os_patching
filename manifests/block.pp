# @summary Block os_patching tasks from being run on a node
class os_patching::block (
  Boolean $block_patching = false,
  String $block_reason = undef,
){

  file { '/etc/os_patching/block.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template("${module_name}/block.conf.erb"),
    require => File['/etc/os_patching'],
    notify  => Exec['/usr/local/bin/os_patching_fact_generation.sh']
  }
}
