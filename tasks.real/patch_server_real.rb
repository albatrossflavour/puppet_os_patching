#!/opt/puppetlabs/puppet/bin/ruby

require 'rbconfig'
require 'json'
require 'syslog/logger'
require 'time'
require 'timeout'
require 'facter'
require 'logger'
require 'pp'

$stdout.sync = true
starttime = Time.now.iso8601

# Parse input, get params in scope, configure logging
params = OsPatching::OsPatching.get_params(starttime)
log = OsPatching::OsPatching.get_logger(params)

# Update the current fact values for packages that need updating, etc
OsPatching::OsPatching.refresh_facts(starttime)
# ...parse the result
facts = {
  values: {
    os: Facter.value(:os),
    os_patching: OsPatching::OsPatching.fact,
  }
}
log.debug("Facts: #{facts.pretty_inspect}")

OsPatching::OsPatching.supported_platform(starttime, facts[:values][:os]['family'])

# Figure out if we need to reboot
def reboot_required(family, release, reboot)
  # Do the easy stuff first
  if ['always', 'patched'].include?(reboot)
    true
  elsif reboot == 'never'
    false
  elsif family == 'RedHat' && File.file?('/usr/bin/needs-restarting') && reboot == 'smart'
    response = ''
    if release.to_i > 6
      status, _output, = OsPatching::OsPatching.run_with_timeout('/usr/bin/needs-restarting -r')
      response = if status != 0
                   true
                 else
                   false
                 end
    elsif release.to_i == 6
      # If needs restart returns processes on RHEL6, consider that the node
      # needs a reboot
      status, output = OsPatching::OsPatching.run_with_timeout('/usr/bin/needs-restarting')
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
  elsif family == 'Debian' && File.file?('/var/run/reboot-required') && reboot == 'smart'
    true
  elsif family == 'Debian'
    false
  else
    false
  end
end

# Get the pinned packages
pinned_pkgs = facts[:values][:os_patching]['pinned_packages']

# Should we clean the cache prior to starting?
if params['clean_cache'] && params['clean_cache'] == true
  OsPatching::OsPatching.clean_cache(starttime, facts[:values][:os]['family'])
end

# Refresh the patching fact cache and re-read os-patching facts
OsPatching::OsPatching.refresh_facts(starttime)
facts[:values][:os_patching] = OsPatching::OsPatching.fact

# Let's figure out the reboot gordian knot
#
# If the override is set, it doesn't matter that anything else is set to at this point
reboot_override = facts[:values][:os_patching]['reboot_override']
reboot_param = params['reboot']
reboot = ''
if reboot_override == 'always'
  reboot = 'always'
elsif ['never', false].include?(reboot_override)
  reboot = 'never'
elsif ['patched', true].include?(reboot_override)
  reboot = 'patched'
elsif reboot_override == 'smart'
  reboot = 'smart'
elsif reboot_override == 'default'
  if reboot_param
    if reboot_param == 'always'
      reboot = 'always'
    elsif ['never', false].include?(reboot_param)
      reboot = 'never'
    elsif ['patched', true].include?(reboot_param)
      reboot = 'patched'
    elsif reboot_param == 'smart'
      reboot = 'smart'
    else
      OsPatching::OsPatching.err('108', 'os_patching/params', 'Invalid parameter for reboot', starttime)
    end
  else
    reboot = 'never'
  end
else
  OsPatching::OsPatching.err(105, 'os_patching/reboot_override', 'Fact reboot_override invalid', starttime)
end

if reboot_override != reboot_param && reboot_override != 'default'
  log.info "Reboot override set to #{reboot_override}, reboot parameter set to #{reboot_param}.  Using '#{reboot_override}'"
end

log.info "Reboot after patching set to #{reboot}"

# Should we only apply security patches?
security_only = ''
if params['security_only']
  if params['security_only'] == true
    security_only = true
  elsif params['security_only'] == false
    security_only = false
  else
    OsPatching::OsPatching.err('109', 'os_patching/params', 'Invalid boolean to security_only parameter', starttime)
  end
else
  security_only = false
end
log.info "Apply only security patches set to #{security_only}"

# Have we had any yum parameter specified?
yum_params = if params['yum_params']
               params['yum_params']
             else
               ''
             end

# Make sure we're not doing something unsafe
if yum_params =~ %r{[\$\|\/;`&]}
  OsPatching::OsPatching.err('110', 'os_patching/yum_params', 'Unsafe content in yum_params', starttime)
end

# Have we had any dpkg parameter specified?
dpkg_params = if params['dpkg_params']
                params['dpkg_params']
              else
                ''
              end

# Make sure we're not doing something unsafe
if dpkg_params =~ %r{[\$\|\/;`&]}
  OsPatching::OsPatching.err('110', 'os_patching/dpkg_params', 'Unsafe content in dpkg_params', starttime)
end

log.debug "dpkg params: #{dpkg_params}"

# Set the timeout for the patch run
if params['timeout']
  if params['timeout'] > 0
    timeout = params['timeout']
  else
    OsPatching::OsPatching.err('121', 'os_patching/timeout', "timeout set to #{timeout} seconds - invalid", starttime)
  end
else
  timeout = 3600
end

# Is the patching blocker flag set?
blocker = facts[:values][:os_patching]['blocked']
if blocker.to_s.chomp == 'true'
  # Patching is blocked, list the reasons and error
  # need to error as it SHOULDN'T ever happen if you
  # use the right workflow through tasks.
  log.error 'Patching blocked, not continuing'
  block_reason = facts[:values][:os_patching]['blocker_reasons']
  err(100, 'os_patching/blocked', "Patching blocked #{block_reason}", starttime)
end

# Should we look at security or all patches to determine if we need to patch?
# (requires RedHat subscription or Debian based distro... for now)
if security_only == true
  updatecount = facts[:values][:os_patching]['security_package_update_count']
  securityflag = '--security'
else
  updatecount = facts[:values][:os_patching]['package_update_count']
  securityflag = ''
end

# There are no updates available, exit cleanly rebooting if the override flag is set
if updatecount.zero?
  if reboot == 'always'
    log.error 'Rebooting'

    OsPatching::OsPatching.output(
      return: 'Success',
      reboot: reboot,
      security: security_only,
      message: 'No patches to apply, reboot triggered',
      packages_updated: '',
      debug: '',
      job_id: '',
      pinned_packages: pinned_pkgs,
      start_time: starttime,
    )

    $stdout.flush
    log.info 'No patches to apply, rebooting as requested'
    p1 = fork { system('nohup /sbin/shutdown -r +1 2>/dev/null 1>/dev/null &') }
    Process.detach(p1)
  else
    OsPatching::OsPatching.output(
      return: 'Success',
      reboot: reboot,
      security: security_only,
      message: 'No patches to apply',
      packages_updated: '',
      debug: '',
      job_id: '',
      pinned_packages: pinned_pkgs,
      start_time: starttime,
    )
    log.info 'No patches to apply, exiting'
  end
  exit(0)
end

# Run the patching
if facts[:values][:os]['family'] == 'RedHat'
  log.info 'Running yum upgrade'
  log.debug "Timeout value set to : #{timeout}"
  yum_end = ''
  status, output = OsPatching::OsPatching.run_with_timeout("yum #{yum_params} #{securityflag} upgrade -y", timeout, 2)
  OsPatching::OsPatching.err(status, 'os_patching/yum', "yum upgrade returned non-zero (#{status}) : #{output}", starttime) if status != 0

  if facts[:values][:os]['release']['major'].to_i > 5
    # Capture the yum job ID
    log.info 'Getting yum job ID'
    job = ''
    status, yum_id = OsPatching::OsPatching.run_with_timeout('yum history')
    OsPatching::OsPatching.err(status, 'os_patching/yum', yum_id, starttime) if status != 0
    yum_id.split("\n").each do |line|
      # Quite the regex.  This pulls out fields 1 & 3 from the first info line
      # from `yum history`,  which look like this :
      # ID     | Login user               | Date and time    | 8< SNIP >8
      # ------------------------------------------------------ 8< SNIP >8
      #     69 | System <unset>           | 2018-09-17 17:18 | 8< SNIP >8
      matchdata = line.to_s.match(/^\s+(\d+)\s*\|\s*[\w\-<> ]*\|\s*([\d:\- ]*)/)
      next unless matchdata
      job = matchdata[1]
      yum_end = matchdata[2]
      break
    end

    # Fail if we didn't capture a job ID
    OsPatching::OsPatching.err(1, 'os_patching/yum', 'yum job ID not found', starttime) if job.empty?

    # Fail if we didn't capture a job time
    OsPatching::OsPatching.err(1, 'os_patching/yum', 'yum job time not found', starttime) if yum_end.empty?

    # Check that the first yum history entry was after the yum_start time
    # we captured.  Append ':59' to the date as yum history only gives the
    # minute and if yum bails, it will usually be pretty quick
    parsed_end = Time.parse(yum_end + ':59').iso8601
    OsPatching::OsPatching.err(1, 'os_patching/yum', 'Yum did not appear to run', starttime) if parsed_end < starttime

    # Capture the yum return code
    log.debug "Getting yum return code for job #{job}"
    status, yum_status = OsPatching::OsPatching.run_with_timeout("yum history info #{job}")
    yum_return = ''
    OsPatching::OsPatching.err(status, 'os_patching/yum', yum_status, starttime) if status != 0
    yum_status.split("\n").each do |line|
      matchdata = line.match(/^Return-Code\s+:\s+(.*)$/)
      next unless matchdata
      yum_return = matchdata[1]
      break
    end

    OsPatching::OsPatching.err(status, 'os_patching/yum', 'yum return code not found', starttime) if yum_return.empty?

    pkg_hash = {}
    # Pull out the updated package list from yum history
    log.debug "Getting updated package list for job #{job}"
    status, updated_packages = OsPatching::OsPatching.run_with_timeout("yum history info #{job}")
    OsPatching::OsPatching.err(status, 'os_patching/yum', updated_packages, starttime) if status != 0
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

  OsPatching::OsPatching.output(
    return: yum_return,
    reboot: reboot,
    security: security_only,
    message: 'Patching complete',
    packages_updated: pkg_hash,
    debug: output,
    job_id: job,
    pinned_packages: pinned_pkgs,
    start_time: starttime,
  )
  log.info 'Patching complete'
elsif facts[:values][:os]['family'] == 'Debian'
  # Are we doing security only patching?
  apt_mode = ''
  pkg_list = []
  if security_only == true
    pkg_list = facts[:values][:os_patching]['security_package_updates']
    apt_mode = "install " + pkg_list.join(" ")
  else
    pkg_list = facts[:values][:os_patching]['package_updates']
    apt_mode = 'dist-upgrade'
  end

  # Do the patching
  log.debug "Running apt #{apt_mode}"
  deb_front = 'DEBIAN_FRONTEND=noninteractive'
  deb_opts = '-o Apt::Get::Purge=false -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef --no-install-recommends'
  status, stderrout = OsPatching::OsPatching.run_with_timeout("#{deb_front} apt-get #{dpkg_params} -y #{deb_opts} #{apt_mode}")
  OsPatching::OsPatching.err(status, 'os_patching/apt', stderrout, starttime) if status != 0
  OsPatching::OsPatching.output(
    return:  'Success',
    reboot: reboot,
    security: security_only,
    message: 'Patching complete',
    packages_updated: pkg_list,
    debug: stderrout,
    job_id: '',
    pinned_packages: pinned_pkgs,
    start_time: starttime,
  )
  log.info 'Patching complete'
else
  # Only works on Redhat & Debian at the moment
  log.error 'Unsupported OS - exiting'
  OsPatching::OsPatching.err(200, 'os_patching/unsupported_os', 'Unsupported OS', starttime)
end

# Refresh the facts now that we've patched
# Refresh the patching fact cache and re-read os-patching facts
OsPatching::OsPatching.refresh_facts(starttime)
facts[:values][:os_patching] = OsPatching::OsPatching.fact

OsPatching::OsPatching.err(status, 'os_patching/fact', _fact_out, starttime) if status != 0

# Reboot if the task has been told to and there is a requirement OR if reboot_override is set to true
needs_reboot = reboot_required(facts[:values][:os]['family'], facts[:values][:os]['release']['major'], reboot)
log.info "reboot_required returning #{needs_reboot}"
if needs_reboot == true
  log.info 'Rebooting'
  p1 = fork { system('nohup /sbin/shutdown -r +1 2>/dev/null 1>/dev/null &') }
  Process.detach(p1)
end
log.info 'os_patching run complete'
exit 0
