# @PDQTest
# PARAMETERS:
# - dpkg_params : Optional[String]
#   Any additional parameters to include in the dpkg command
# - reboot : Optional[Variant[Boolean, Enum['always', 'never', 'patched', 'smart']]]
#   Should the server reboot after patching has been applied? (Defaults to "never")
# - security_only : Optional[Boolean]
#   Limit patches to those tagged as security related? (Defaults to false)
# - timeout : Optional[Integer]
#   How many seconds should we wait until timing out the patch run? (Defaults to 3600 seconds)
# - yum_params : Optional[String]
# Any additional parameters to include in the yum upgrade command (such as including/excluding repos)
if $facts['os']['family'] == 'RedHat' {
  $params = {
    'yum_params' => '--errorlevel=10',
    'reboot'     => 'always',
    'debug'      => 'debug',
  }
} elsif $facts['os']['family'] == 'Debian' {
  $params = {
    'dpkg_params' => '-a i386',
    'reboot'      => 'always',
    'debug'       => 'debug',
  }
} else {
  fail("Unsupported OS ${facts['os']['family']} in testcase")
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
  command => 'bash -c \'cat /tmp/os_patching/params.json | /testcase/tasks/patch_server.rb  > /tmp/os_patching/output.txt 2>&1 \'',
  path    => '/bin:/usr/bin',
  creates => '/tmp/os_patching/output.txt',
}