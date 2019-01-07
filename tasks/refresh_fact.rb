#!/opt/puppetlabs/puppet/bin/ruby

require 'rbconfig'
is_windows = (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
if is_windows
  puts 'Cannot run os_patching::refresh_fact on Windows'
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

# Update the fact cache
clean_out, stderr, status = Open3.capture3('/usr/local/bin/os_patching_fact_generation.sh')
err(status, 'os_patching/fact_cache_update', stderr, starttime) if status != 0
output(status, 'Patching fact cache updated', clean_out, starttime)
log.info 'Patching fact cache updated'
