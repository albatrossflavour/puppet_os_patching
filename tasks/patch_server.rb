#!/opt/puppetlabs/puppet/bin/ruby

require 'rbconfig'
is_windows = (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
if is_windows
  puts 'Cannot run os_patching::patch_server on Windows'
  exit 1
end

require 'open3'
require 'json'
require 'syslog/logger'
require 'time'
require 'timeout'

$stdout.sync = true

facter = '/opt/puppetlabs/puppet/bin/facter'

log = Syslog::Logger.new 'os_patching'
starttime = Time.now.iso8601
BUFFER_SIZE = 4096

# Function to write out the history file after patching
def history(dts, message, code, reboot, security, job)
  historyfile = '/etc/os_patching/run_history'
  open(historyfile, 'a') do |f|
    f.puts "#{dts}|#{message}|#{code}|#{reboot}|#{security}|#{job}"
  end
end

def run_with_timeout(command, timeout, tick)
  output = ''
  status = 99
  begin
    # Start task in another thread, which spawns a process
    stdin, stderrout, thread = Open3.popen2e(command)
    # Get the pid of the spawned process
    pid = thread[:pid]
    start = Time.now

    while (Time.now - start) < timeout && thread.alive?
      # Wait up to `tick` seconds for output/error data
      Kernel.select([stderrout], nil, nil, tick)
      # Try to read the data
      begin
        output << stderrout.read_nonblock(BUFFER_SIZE)
      rescue IO::WaitReadable
        # A read would block, so loop around for another select
        sleep 1
      rescue EOFError
        # Command has completed, not really an error...
        break
      end
    end
    status = thread.value.exitstatus
    # Give Ruby time to clean up the other thread
    sleep 1

    if thread.alive?
      # We need to kill the process, because killing the thread leaves
      # the process alive but detached, annoyingly enough.
      Process.kill('TERM', pid)
      err('403', 'os_patching/patching', "TIMEOUT AFTER #{timeout} seconds\n#{output}", start)
    end
  ensure
    stdin.close if stdin
    stderrout.close if stderrout
    status = thread.value.exitstatus
  end
  return status,output
end

# Default output function
def output(returncode, reboot, security, message, packages_updated, debug, job_id, pinned_packages, starttime)
  endtime = Time.now.iso8601
  json = {
    :return           => returncode,
    :reboot           => reboot,
    :security         => security,
    :message          => message,
    :packages_updated => packages_updated,
    :debug            => debug,
    :job_id           => job_id,
    :pinned_packages  => pinned_packages,
    :start_time       => starttime,
    :end_time         => endtime,
  }
  puts JSON.pretty_generate(json)
  history(starttime, message, returncode, reboot, security, job_id)
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

# Figure out if we need to reboot
def reboot_required(family, release)
  if family == 'RedHat' && File.file?('/usr/bin/needs-restarting')
    response = ''
    if release.to_i > 6
      _output, _stderr, status = Open3.capture3('/usr/bin/needs-restarting -r')
      response = if status != 0
                   true
                 else
                   false
                 end
    elsif release.to_i == 6
      # If needs restart returns processes on RHEL6, consider that the node
      # needs a reboot
      output, stderr, _status = Open3.capture3('/usr/bin/needs-restarting')
      response = if output.empty? && stderr.empty?
                   false
                 else
                   true
                 end
    else
      # Needs-restart doesn't exist before RHEL6
      response = true
    end
    response
  elsif family == 'Redhat'
    false
  elsif family == 'Debian' && File.file?('/var/run/reboot-required')
    true
  elsif family == 'Debian'
    false
  end
end

# Parse input
params = JSON.parse(STDIN.read)

# Cache fact data to speed things up
log.error 'os_patching run started'
log.error 'Running os_patching fact refresh'
_fact_out, stderr, status = Open3.capture3('/usr/local/bin/os_patching_fact_generation.sh')
err(status, 'os_patching/fact_refresh', stderr, starttime) if status != 0
log.error 'Gathering facts'
full_facts, stderr, status = Open3.capture3(facter, '-p', '-j')
err(status, 'os_patching/facter', stderr, starttime) if status != 0
facts = JSON.parse(full_facts)
pinned_pkgs = facts['os_patching']['pinned_packages']

# Should we do a reboot?
if params['reboot']
  if params['reboot'] == true
    reboot = true
  elsif params['reboot'] == false
    reboot = false
  else
    err('108', 'os_patching/params', 'Invalid boolean to reboot parameter', starttime)
  end
else
  reboot = false
end

# Is the reboot_override fact set?
reboot_override = facts['os_patching']['reboot_override']
if reboot_override == 'Invalid Entry'
  err(105, 'os_patching/reboot_override', 'Fact reboot_override invalid', starttime)
elsif reboot_override == true && reboot == false
  log.error 'Reboot override set to true but task said no.  Will reboot'
  reboot = true
elsif reboot_override == false && reboot == true
  log.error 'Reboot override set to false but task said yes.  Will not reboot'
  reboot = false
end

log.error "Reboot after patching set to #{reboot}"

# Should we only apply security patches?
security_only = ''
if params['security_only']
  if params['security_only'] == true
    security_only = true
  elsif params['security_only'] == false
    security_only = false
  else
    err('109', 'os_patching/params', 'Invalid boolean to security_only parameter', starttime)
  end
else
  security_only = false
end
log.error "Apply only security patches set to #{security_only}"

# Have we had any yum parameter specified?
yum_params = if params['yum_params']
               params['yum_params']
             else
               ''
             end

# Make sure we're not doing something unsafe
if yum_params =~ %r{[\$\|\/;`&]}
  err('110', 'os_patching/yum_params', 'Unsafe content in yum_params', starttime)
end

# Have we had any dpkg parameter specified?
dpkg_params = if params['dpkg_params']
                params['dpkg_params']
              else
                ''
              end

# Make sure we're not doing something unsafe
if dpkg_params =~ %r{[\$\|\/;`&]}
  err('110', 'os_patching/dpkg_params', 'Unsafe content in dpkg_params', starttime)
end

# Set the timeout for the patch run
if params['timeout']
  if params['timeout'] > 0
    timeout = params['timeout']
  else
    err('121', 'os_patching/timeout', "timeout set to #{timeout} seconds - invalid", starttime)
  end
else
  timeout = 3600
end

# Is the patching blocker flag set?
blocker = facts['os_patching']['blocked']
if blocker.to_s.chomp == 'true'
  # Patching is blocked, list the reasons and error
  # need to error as it SHOULDN'T ever happen if you
  # use the right workflow through tasks.
  log.error 'Patching blocked, not continuing'
  block_reason = facts['os_patching']['blocker_reasons']
  err(100, 'os_patching/blocked', "Patching blocked #{block_reason}", starttime)
end

# Should we look at security or all patches to determine if we need to patch?
# (requires RedHat subscription or Debian based distro... for now)
if security_only == true
  updatecount = facts['os_patching']['security_package_update_count']
  securityflag = '--security'
else
  updatecount = facts['os_patching']['package_update_count']
  securityflag = ''
end

# There are no updates available, exit cleanly rebooting if the override flag is set
if updatecount.zero?
  if reboot_override == true
    log.error 'Rebooting'
    output('Success', reboot, security_only, 'No patches to apply, reboot triggered', '', '', '', pinned_pkgs, starttime)
    $stdout.flush
    log.error 'No patches to apply, rebooting as requested'
    p1 = fork { system('nohup /sbin/shutdown -r +1 2>/dev/null 1>/dev/null &') }
    Process.detach(p1)
  else
    output('Success', reboot, security_only, 'No patches to apply', '', '', '', pinned_pkgs, starttime)
    log.error 'No patches to apply, exiting'
  end
  exit(0)
end

# Run the patching
if facts['os']['family'] == 'RedHat'
  log.error 'Running yum upgrade'
  log.error "Timeout value set to : #{timeout}"
  yum_start = Time.now
  yum_end = ''
  status, output = run_with_timeout("yum #{yum_params} #{securityflag} upgrade -y", timeout, 2)
  err(status, 'os_patching/yum', "yum upgrade returned non-zero (#{status}) : #{output}", starttime) if status != 0

  if facts['os']['release']['major'].to_i > 5
    # Capture the yum job ID
    log.error 'Getting yum job ID'
    job = ''
    yum_id, stderr, status = Open3.capture3('yum history')
    err(status, 'os_patching/yum', stderr, starttime) if status != 0
    yum_id.split("\n").each do |line|
      matchdata = line.to_s.match(/^\s+(\d+)\s*\|\s*[\w\-<> ]*\|\s*([\d:\- ]*)/)
      next unless matchdata
      if matchdata[1]
        job = matchdata[1]
        yum_end = matchdata[1]
        break
      end
    end

    # Fail if we didn't capture a job ID
    err(1, 'os_patching/yum', 'yum job ID not found', starttime) if job.empty?

    # Fail if we didn't capture a job time
    err(1, 'os_patching/yum', 'yum job time not found', starttime) if yum_end.empty?

    # Check that the first yum history entry was after the yum_start time we captured
    parsed_end = Time.parse(yum_end) 
    err(1, 'os_patching/yum', 'Yum did not appear to run', starttime) if parsed_end < yum_start

    # Capture the yum return code
    log.error "Getting yum return code for job #{job}"
    yum_status, stderr, status = Open3.capture3("yum history info #{job}")
    yum_return = ''
    err(status, 'os_patching/yum', stderr, starttime) if status != 0
    yum_status.split("\n").each do |line|
      matchdata = line.match(/^Return-Code\s+:\s+(.*)$/)
      next unless matchdata
      yum_return = matchdata[1]
      break
    end

    err(status, 'os_patching/yum', 'yum return code not found', starttime) if yum_return.empty?

    pkg_hash = {}
    # Pull out the updated package list from yum history
    log.error "Getting updated package list  for job #{job}"
    updated_packages, stderr, status = Open3.capture3("yum history info #{job}")
    err(status, 'os_patching/yum', stderr, starttime) if status != 0
    updated_packages.split("\n").each do |line|
      matchdata = line.match(/^\s+(Installed|Install|Upgraded|Erased|Updated)\s+(\S+)\s/)
      next unless matchdata
      pkg_hash[matchdata[2]] = matchdata[1]
    end
  else
    yum_return = 'Assumed successful - further details not available on RHEL5'
    job = 'Unsupported on RHEL5'
    pkg_hash = {}
  end

  output(yum_return, reboot, security_only, 'Patching complete', pkg_hash, yum_output, job, pinned_pkgs, starttime)
  log.error 'Patching complete'
elsif facts['os']['family'] == 'Debian'
  # The security only workflow for Debain is a little complex, retiring it for now
  if security_only == true
    log.error 'Debian upgrades, security only not currently supported'
    err(101, 'os_patching/security_only', 'Security only not supported on Debian at this point', starttime)
  end

  log.error 'Getting package update list'
  updated_packages, stderr, status = Open3.capture3("apt-get dist-upgrade -s #{dpkg_params} | awk '/^Inst/ {print $2}'")
  err(status, 'os_patching/apt', stderr, starttime) if status != 0
  pkg_array = updated_packages.split

  # Do the patching
  log.error 'Running apt update'
  deb_front = 'DEBIAN_FRONTEND=noninteractive'
  deb_opts = '-o Apt::Get::Purge=false -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef --no-install-recommends'
  apt_std_out, stderr, status = Open3.capture3("#{deb_front} apt-get #{dpkg_params} -y #{deb_opts} dist-upgrade")
  err(status, 'os_patching/apt', stderr, starttime) if status != 0

  output('Success', reboot, security_only, 'Patching complete', pkg_array, apt_std_out, '', pinned_pkgs, starttime)
  log.error 'Patching complete'
else
  # Only works on Redhat & Debian at the moment
  log.error 'Unsupported OS - exiting'
  err(200, 'os_patching/unsupported_os', 'Unsupported OS', starttime)
end

# Refresh the facts now that we've patched
log.error 'Running os_patching fact refresh'
_fact_out, stderr, status = Open3.capture3('/usr/local/bin/os_patching_fact_generation.sh')
err(status, 'os_patching/fact', stderr, starttime) if status != 0

# Reboot if the task has been told to and there is a requirement OR if reboot_override is set to true
needs_reboot = reboot_required(facts['os']['family'], facts['os']['release']['major'])
if (reboot == true && needs_reboot == true) || reboot_override == true
  log.error 'Rebooting'
  p1 = fork { system('nohup /sbin/shutdown -r +1 2>/dev/null 1>/dev/null &') }
  Process.detach(p1)
end
log.error 'os_patching run complete'
exit 0
