#!/opt/puppetlabs/puppet/bin/ruby

require 'open3'
require 'json'
require 'syslog/logger'

facter = '/opt/puppetlabs/puppet/bin/facter'

log = Syslog::Logger.new 'os_patching'

def output(returncode,reboot,security,message,packages_updated,debug,job_id,pinned_packages)
  json = {
    :return => returncode,
    :reboot => reboot,
    :security => security,
    :message => message,
    :packages_updated => packages_updated,
    :debug => debug,
    :job_id => job_id,
    :pinned_packages => pinned_packages
  }
  puts JSON.pretty_generate(json)
end

def err(code,kind,message)
  exitcode = code.to_s.split.last
  json = { :_error => {
	   :msg => "Task exited : #{exitcode}\n#{message}",
	   :kind => kind,
	   :details => { :exitcode => exitcode }
  }}

  puts JSON.pretty_generate(json)
  log = Syslog::Logger.new 'os_patching'
  log.error "ERROR : #{kind} : #{exitcode} : #{message}"
  exit(exitcode.to_i)
end

# Cache fact data to speed things up
log.debug 'Gathering facts'
full_facts,stderr,status = Open3.capture3("#{facter} -p -j")
err(status,"os_patching/facter",stderr) if status != 0
facts = {}
facts = JSON.parse(full_facts)
pinned_pkgs = facts['os_patching']['pinned_packages']

# Should we do a reboot?
# PT_reboot is set by puppet as part of the task
if ( ENV["PT_reboot"] == "true" )
  reboot = true
else
  reboot = false
end

log.debug "Reboot after patching set to #{reboot}"

# Should we only apply security patches?
# PT_security_only is set by puppet as part of the task
if ( ENV["PT_security_only"] == "true" )
  security_only = true
else
  security_only = false
end
log.debug "Apply only security patches set to #{security_only}"


# Is the patching blocker flag set?
blocker = facts['os_patching']['blocked']
if (blocker.to_s.chomp == "true")
  # Patching is blocked, list the reasons and error
  # need to error as it SHOULDN'T ever happen if you
  # use the right workflow through tasks.
  log.error "Patching blocked, not continuing"
  block_reason = facts['os_patching']['blocker_reasons']
  err(100,"os_patching/blocked","Patching blocked #{block_reason}")
end

# Should we look at security or all patches to determine if we need to patch?
# (requires RedHat subscription or Debian based distro... for now)
if (security_only == true)
  updatecount = facts['os_patching']['security_package_update_count']
  securityflag = '--security'
else
  updatecount = facts['os_patching']['package_update_count']
  securityflag = ''
end

# There are no updates available, exit cleanly
if (updatecount == 0)
  output('Success',reboot,security_only,'No patches to apply','','','',pinned_pkgs)
  log.info "No patches to apply, exiting"
  exit(0)
end

# Run the patching
if (facts['os']['family'] == "RedHat")
  log.debug 'Running yum upgrade'
  yum_std_out,stderr,status = Open3.capture3("/bin/yum #{securityflag} upgrade -y")
  err(status,"os_patching/yum",stderr) if status != 0

  log.debug 'Getting yum job ID'
  yum_id,stderr,status = Open3.capture3("yum history | grep -E \"^[[:space:]]\" | awk '{print $1}' | head -1")
  err(status,"os_patching/yum",stderr) if status != 0

  log.debug "Getting yum return code for job #{yum_id.chomp}"
  yum_status,stderr,status = Open3.capture3("yum history info #{yum_id.chomp} | awk '/^Return-Code/ {print $3}'")
  err(status,"os_patching/yum",stderr) if status != 0

  log.debug "Getting updated package list	for job #{yum_id.chomp}"
  updated_packages,stderr,status = Open3.capture3("yum history info #{yum_id.chomp} | awk '/Updated/ {print $2}'")
  err(status,"os_patching/yum",stderr) if status != 0
  pkg_array = updated_packages.split

  output(yum_status.chomp,reboot,security_only,"Patching complete",pkg_array,yum_std_out,yum_id.chomp,pinned_pkgs)
  log.debug "Patching complete"
elsif (facts['os']['family'] == "Debian")
  if (security_only == true)
    log.debug 'Debian upgrades, security only not currently supported'
    err(101,"os_patching/security_only","Security only not supported on Debian at this point")
  end

  log.debug 'Getting package update list'
  updated_packages,stderr,status = Open3.capture3("apt-get upgrade -s | awk '/^Inst/ {print $2}'")
  err(status,"os_patching/apt",stderr) if status != 0
  pkg_array = updated_packages.split

  log.debug 'Running apt update'
  apt_std_out,stderr,status = Open3.capture3("DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade")
  err(status,"os_patching/apt",stderr) if status != 0

  output('Success',reboot,security_only,"Patching complete",pkg_array,apt_std_out,'',pinned_pkgs)
  log.debug "Patching complete"
else
  log.error "Unsupported OS - exiting"
  err(200,"os_patching/unsupported_os","Unsupported OS")
end

log.debug 'Running os_patching fact refresh'
fact_out,stdout,stderr = Open3.capture3('/usr/local/bin/os_patching_fact_generation.sh')
log.debug 'Running puppet agent'
puppet_out,stdout,stderr = Open3.capture3('/opt/puppetlabs/bin/puppet -t')

if (reboot == true)
  log.info 'Rebooting'
  reboot_out,stdout,stderr = Open3.capture3('reboot -r 1')
end
