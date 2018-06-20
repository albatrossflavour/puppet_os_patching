# @summary Block os_patching tasks from being run on a node
class os_patching::block (
  Boolean $block_patching = false,
  String $block_reason = undef,
){
  File {
    owner => 'root',
    group => 'root',
    mode  => '0644',
  }

  file { '/etc/os_patching':
    ensure  => directory,
  }

  file { '/etc/os_patching/block.conf':
    ensure  => file,
    content => template("${module_name}/block.conf.erb"),
  }
}
