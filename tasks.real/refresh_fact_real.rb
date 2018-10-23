#!/opt/puppetlabs/puppet/bin/ruby
require 'time'
require 'facter'

$stdout.sync = true
starttime = Time.now.iso8601
BUFFER_SIZE = 4096

# Cache the facts
facts = {
  values: {
    os: Facter.value(:os),
  },
}

# fail on unsupported
OsPatching::OsPatching.supported_platform(starttime, facts[:values][:os]['family'])

params = OsPatching::OsPatching.get_params(starttime)
timeout = OsPatching::OsPatching.get_timeout(params, starttime)
log = OsPatching::OsPatching.get_logger(params)

# Update the fact cache
clean_out = OsPatching::OsPatching.refresh_facts(starttime, timeout)
OsPatching::OsPatching.output(
  return:  0,
  message: 'Patching fact cache updated',
  debug: clean_out,
  start_time: starttime,
)
log.info 'Patching fact cache updated'
