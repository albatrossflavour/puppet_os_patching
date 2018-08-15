#!/opt/puppetlabs/puppet/bin/ruby

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
  begin
    # Start task in another thread, which spawns a process
    stdin, stderrout, thread = Open3.popen2e(command)
    # Get the pid of the spawned process
    pid = thread[:pid]
    start = Time.now

    while (Time.now - start) < timeout and thread.alive?
      # Wait up to `tick` seconds for output/error data
      Kernel.select([stderrout], nil, nil, tick)
      # Try to read the data
      begin
        output << stderrout.read_nonblock(BUFFER_SIZE)
      rescue IO::WaitReadable
        # A read would block, so loop around for another select
      rescue EOFError
        # Command has completed, not really an error...
        break
      end
    end
    # Give Ruby time to clean up the other thread
    sleep 1

    if thread.alive?
      # We need to kill the process, because killing the thread leaves
      # the process alive but detached, annoyingly enough.
      Process.kill("TERM", pid)
      err('403', 'os_patching/fact_refresh', "TIMEOUT AFTER #{timeout} seconds\n#{output}", start)
    end
  ensure
    stdin.close if stdin
    stderrout.close if stderrout
  end
  return output
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
  log = Syslog::Logger.new 'os_patching'
  log.error "ERROR : #{kind} : #{exitcode} : #{message}"
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
    else
      output, _stderr, _status = Open3.capture3('/usr/bin/needs-restarting')
      response = true unless output.empty?
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
log.info 'os_patching run started'
log.debug 'Running os_patching fact refresh'
_fact_out, stderr, status = Open3.capture3('/usr/local/bin/os_patching_fact_generation.sh')
err(status, 'os_patching/fact_refresh', stderr, starttime) if status != 0
log.debug 'Gathering facts'
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

log.debug "Reboot after patching set to #{reboot}"

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
log.debug "Apply only security patches set to #{security_only}"

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
    log.info 'Rebooting'
    output('Success', reboot, security_only, 'No patches to apply, reboot triggered', '', '', '', pinned_pkgs, starttime)
    $stdout.flush
    log.info 'No patches to apply, rebooting as requested'
    p1 = fork { system('nohup /sbin/shutdown -r +1 2>/dev/null 1>/dev/null &') }
    Process.detach(p1)
  else
    output('Success', reboot, security_only, 'No patches to apply', '', '', '', pinned_pkgs, starttime)
    log.info 'No patches to apply, exiting'
  end
  exit(0)
end

yum_output = ''
# Run the patching
if facts['os']['family'] == 'RedHat'
  log.debug 'Running yum upgrade'
  log.debug "Timeout value set to : #{timeout}"
  yum_stdout = run_with_timeout("yum #{yum_params} #{securityflag} upgrade -y",timeout,2)

  # Capture the yum job ID
  log.debug 'Getting yum job ID'
  job = ''
  yum_id, stderr, status = Open3.capture3('yum history')
  err(status, 'os_patching/yum', stderr, starttime) if status != 0
  yum_id.split("\n").each do |line|
    matchdata = line.to_s.match(/^\s+(\d+)\s/)
    next unless matchdata
    if matchdata[1]
      job = matchdata[1]
      break
    end
  end

  # Capture the yum return code
  log.debug "Getting yum return code for job #{job}"
  yum_status, stderr, status = Open3.capture3("yum history info #{job}")
  yum_return = ''
  err(status, 'os_patching/yum', stderr, starttime) if status != 0
  yum_status.split("\n").each do |line|
    matchdata = line.match(/^Return-Code\s+:\s+(.*)$/)
    next unless matchdata
    yum_return = matchdata[1]
  end

  pkg_hash = {}
  # Pull out the updated package list from yum history
  log.debug "Getting updated package list  for job #{job}"
  updated_packages, stderr, status = Open3.capture3("yum history info #{job}")
  err(status, 'os_patching/yum', stderr, starttime) if status != 0
  updated_packages.split("\n").each do |line|
    matchdata = line.match(/^\s+(Installed|Upgraded|Erased|Updated)\s+(\S+)\s/)
    next unless matchdata
    pkg_hash[matchdata[2]] = matchdata[1]
  end

  output(yum_return, reboot, security_only, 'Patching complete', pkg_hash, yum_output, job, pinned_pkgs, starttime)
  log.debug 'Patching complete'
elsif facts['os']['family'] == 'Debian'
  # The security only workflow for Debain is a little complex, retiring it for now
  if security_only == true
    log.debug 'Debian upgrades, security only not currently supported'
    err(101, 'os_patching/security_only', 'Security only not supported on Debian at this point', starttime)
  end

  log.debug 'Getting package update list'
  updated_packages, stderr, status = Open3.capture3("apt-get dist-upgrade -s #{dpkg_params} | awk '/^Inst/ {print $2}'")
  err(status, 'os_patching/apt', stderr, starttime) if status != 0
  pkg_array = updated_packages.split

  # Do the patching
  log.debug 'Running apt update'
  deb_front = 'DEBIAN_FRONTEND=noninteractive'
  deb_opts = '-o Apt::Get::Purge=false -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef --no-install-recommends'
  apt_std_out, stderr, status = Open3.capture3("#{deb_front} apt-get #{dpkg_params} -y #{deb_opts} dist-upgrade")
  err(status, 'os_patching/apt', stderr, starttime) if status != 0

  output('Success', reboot, security_only, 'Patching complete', pkg_array, apt_std_out, '', pinned_pkgs, starttime)
  log.debug 'Patching complete'
else
  # Only works on Redhat & Debian at the moment
  log.error 'Unsupported OS - exiting'
  err(200, 'os_patching/unsupported_os', 'Unsupported OS', starttime)
end

# Refresh the facts now that we've patched
log.debug 'Running os_patching fact refresh'
_fact_out, stderr, status = Open3.capture3('/usr/local/bin/os_patching_fact_generation.sh')
err(status, 'os_patching/fact', stderr, starttime) if status != 0

# Reboot if the task has been told to and there is a requirement OR if reboot_override is set to true
needs_reboot = reboot_required(facts['os']['family'], facts['os']['release']['major'])
if (reboot == true && needs_reboot == true) || reboot_override == true
  log.info 'Rebooting'
  p1 = fork { system('nohup /sbin/shutdown -r +1 2>/dev/null 1>/dev/null &') }
  Process.detach(p1)
end
log.info 'os_patching run complete'
