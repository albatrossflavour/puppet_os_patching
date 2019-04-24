#!/opt/puppetlabs/puppet/bin/ruby

require 'rbconfig'
is_windows = (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
if is_windows
  puts 'Cannot run os_patching::clean_cache on Windows'
  exit 1
end

require 'open3'
require 'json'
require 'syslog/logger'
require 'time'
require 'timeout'

$stdout.sync = true

log = Syslog::Logger.new 'os_patching'
starttime = Time.now.iso8601
BUFFER_SIZE = 4096

# Default output function
def output(returncode, message, debug, starttime)
  endtime = Time.now.iso8601
  json = {
    :return           => returncode,
    :message          => message,
    :debug            => debug,
    :start_time       => starttime,
    :end_time         => endtime,
  }
  puts JSON.pretty_generate(json)
end

# Error output function
def err(code, kind, message, starttime)
  endtime = Time.now.iso8601
  exitcode = code.to_s.split.last
  json = {
    :_error =>
    {
      :msg        => "Task exited : #{exitcode}\n#{message}",
      :kind       => kind,
      :details    => { :exitcode => exitcode },
      :start_time => starttime,
      :end_time   => endtime,
    },
  }

  puts JSON.pretty_generate(json)
  shortmsg = message.split("\n").first.chomp
  history(starttime, shortmsg, exitcode, '', '', '')
  syslog = Syslog::Logger.new 'os_patching'
  syslog.error "ERROR : #{kind} : #{exitcode} : #{message}"
  exit(exitcode.to_i)
end

# Cache the facts
log.debug 'Gathering facts'
full_facts, stderr, status = Open3.capture3('/opt/puppetlabs/puppet/bin/puppet', 'facts')
err(status, 'os_patching/facter', stderr, starttime) if status != 0
facts = JSON.parse(full_facts)

# Check we are on a supported platform
unless facts['values']['os']['family'] == 'RedHat' || facts['values']['os']['family'] == 'Debian' || facts['values']['os']['family'] == 'Suse'
  err(200, 'os_patching/unsupported_os', 'Unsupported OS', starttime)
end

clean_cache = if facts['values']['os']['family'] == 'RedHat'
                'yum clean all'
              elsif facts['values']['os']['family'] == 'Debian'
                'apt-get clean'
              elsif facts['values']['os']['family'] == 'Suse'
                'zypper cc --all'
              end

# Clean that cache!
clean_out, stderr, status = Open3.capture3(clean_cache)
err(status, 'os_patching/clean_cache', stderr, starttime) if status != 0
output(status, 'Cache cleaned', clean_out, starttime)
log.info 'Cache cleaned'
