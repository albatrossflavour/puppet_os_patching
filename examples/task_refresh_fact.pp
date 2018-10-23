# @PDQTest

$params = {
  'debug'   => 'debug',
  'timeout' => 15,
}

# write the JSON to file and re-read it to avoid fighting the shell...
file { '/tmp/os_patching/params.json':
  ensure  => file,
  owner   => 'root',
  group   => 'root',
  mode    => '0644',
  content => to_json($params),
}

exec { 'check task updates system with params':
  command => 'bash -c \'cat /tmp/os_patching/params.json | /testcase/tasks/refresh_fact.rb  > /tmp/os_patching/output.txt 2>&1 \'',
  path    => '/bin:/usr/bin',
  creates => '/tmp/os_patching/output.txt',
}