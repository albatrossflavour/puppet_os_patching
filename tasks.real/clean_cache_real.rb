#!/opt/puppetlabs/puppet/bin/ruby

require 'facter'
require 'rbconfig'
require 'pp'
require 'open3'
require 'json'
require 'syslog/logger'
require 'time'
require 'timeout'


if OsPatching::OsPatching.is_windows
  puts 'Cannot run os_patching::clean_cache on Windows'
  exit 1
end
$stdout.sync = true
starttime = Time.now.iso8601

BUFFER_SIZE = 4096

# Cache the facts
facts = {
    :values => {
        :os => Facter.value(:os),
    }
}

# params is used to activate debug logging
params = OsPatching::OsPatching.get_params(starttime)
log = OsPatching::OsPatching.get_logger(params)
log.debug("facts: #{facts.pretty_print_inspect}")

# Check we are on a supported platform
unless facts[:values][:os]['family'] == 'RedHat' || facts[:values][:os]['family'] == 'Debian'
  OsPatching::OsPatching.err(200, 'os_patching/unsupported_os', 'Unsupported OS', starttime)
end

clean_cache = if facts[:values][:os]['family'] == 'RedHat'
                'yum clean all'
              elsif facts[:values][:os]['family'] == 'Debian'
                'apt-get update'
              end

# Clean that cache!
status, stderrout = OsPatching::OsPatching.run_with_timeout(clean_cache)
OsPatching::OsPatching.err(status, 'os_patching/clean_cache', stderrout, starttime) if status != 0
OsPatching::OsPatching.output(
  return: status,
  message: 'Cache cleaned',
  debug: stderrout,
  start_time: starttime,
)
log.info 'Cache cleaned'
