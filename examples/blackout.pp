# @PDQTest

exec { 'run the update script and make sure it fails':
  command => 'bash -c "printf \'{}\' | /testcase/tasks/patch_server.rb  > /tmp/output.txt ; true"',
  path    => '/bin:/usr/bin',
  creates => "/tmp/output.txt",
}