#!/opt/puppetlabs/puppet/bin/ruby

# windows logging class
class WinLog
  def initialize
    require 'win32/eventlog'

    # log to send events to
    windows_log = 'Application'

    # source of event shown in event log
    @event_source = 'os_patching'

    # add event source if needed
    # we probably should generate and register an mc file, but the events still show without it
    Win32::EventLog.add_event_source(:source => windows_log, :key_name => @event_source)

    # create logger
    @logger = Win32::EventLog.new
  end

  # match SysLog::Logger event types

  def debug(data)
    @logger.report_event(:event_type => Win32::EventLog::INFO_TYPE, :data => "Debug: #{data}", :source => @event_source)
  end

  def error(data)
    @logger.report_event(:event_type => Win32::EventLog::ERROR_TYPE, :data => data, :source => @event_source)
  end

  def fatal(data)
    @logger.report_event(:event_type => Win32::EventLog::ERROR_TYPE, :data => "FATAL: #{data}", :source => @event_source)
  end

  def info(data)
    @logger.report_event(:event_type => Win32::EventLog::INFO_TYPE, :data => data, :source => @event_source)
  end

  def unknown(data)
    @logger.report_event(:event_type => Win32::EventLog::INFO_TYPE, :data => "Unknown: #{data}", :source => @event_source)
  end

  def warn(data)
    @logger.report_event(:event_type => Win32::EventLog::WARN_TYPE, :data => data, :source => @event_source)
  end
end

require 'rbconfig'
require 'open3'
require 'json'
require 'time'
require 'timeout'

is_windows = (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)

$stdout.sync = true

if is_windows
  # windows
  # create windows event logger
  log = WinLog.new
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
  shortmsg = message.split("\n").first.chomp
  history(starttime, shortmsg, exitcode, '', '', '')
  log = if is_windows
          WinLog.new
        else
          Syslog::Logger.new 'os_patching'
        end
  log.error "ERROR : #{kind} : #{exitcode} : #{message}"
  exit(exitcode.to_i)
end

# Update the fact cache
refresh_out, stderr, status = Open3.capture3(fact_generation_cmd)

# make output more readable if on windows
refresh_out_log = if is_windows
                    refresh_out.split("\n")
                  else
                    refresh_out
                  end

err(status, 'os_patching/fact_cache_update', stderr, starttime) if status != 0
output(status, 'Patching fact cache updated', refresh_out_log, starttime)
log.info 'Patching fact cache updated'
