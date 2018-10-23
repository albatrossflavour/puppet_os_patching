#!/opt/puppetlabs/puppet/bin/ruby
require 'facter'
require 'time'

$stdout.sync = true
starttime = Time.now.iso8601

# Cache the facts
facts = {
  values: {
    os: Facter.value(:os),
  },
}

# fail on unsupported
OsPatching::OsPatching.supported_platform(starttime, facts[:values][:os]['family'])

# params is used to activate debug logging
params = OsPatching::OsPatching.get_params(starttime)
timeout = OsPatching::OsPatching.get_timeout(params, starttime)

log = OsPatching::OsPatching.get_logger(params)
log.debug("facts: #{facts.pretty_print_inspect}")

status, stderrout = OsPatching::OsPatching.clean_cache(starttime, facts[:values][:os]['family'], timeout)
OsPatching::OsPatching.output(
  return: status,
  message: 'Cache cleaned',
  debug: stderrout,
  start_time: starttime,
)
log.info 'Cache cleaned'
