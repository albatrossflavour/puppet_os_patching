#!/opt/puppetlabs/puppet/bin/ruby

require 'rbconfig'
require 'open3'
require 'json'
require 'time'
require 'timeout'

IS_WINDOWS = (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)

$stdout.sync = true

if IS_WINDOWS
  # windows
  # use ruby file logger
  require 'logger'
  log = Logger.new('C:/ProgramData/os_patching/os_patching_refresh_fact_task.log', 'monthly')
  # set paths/commands for windows
  fact_generation_script = 'C:/ProgramData/os_patching/os_patching_fact_generation.ps1'
  fact_generation_cmd = "#{ENV['systemroot']}/system32/WindowsPowerShell/v1.0/powershell.exe -ExecutionPolicy RemoteSigned -file #{fact_generation_script}"
else
  # not windows
  # create syslog logger
  require 'syslog/logger'
  log = Syslog::Logger.new 'os_patching'
  # set paths/commands for linux
  fact_generation_script = '/usr/local/bin/os_patching_fact_generation.sh'
  fact_generation_cmd = fact_generation_script
end

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
  if IS_WINDOWS
    # windows
    # use ruby file logger
    require 'logger'
    log = Logger.new('C:/ProgramData/os_patching/os_patching_refresh_fact_task.log', 'monthly')
  else
    # not windows
    # create syslog logger
    require 'syslog/logger'
    log = Syslog::Logger.new 'os_patching'
  end
  log.error "ERROR : #{kind} : #{exitcode} : #{message}"
  exit(exitcode.to_i)
end

# Update the fact cache
refresh_out, stderr, status = Open3.capture3(fact_generation_cmd)

# make output more readable if on windows
refresh_out_log = if IS_WINDOWS
                    refresh_out.split("\n")
                  else
                    refresh_out
                  end

err(status, 'os_patching/fact_cache_update', stderr, starttime) if status != 0
output(status, 'Patching fact cache updated', refresh_out_log, starttime)
log.info 'Patching fact cache updated'
