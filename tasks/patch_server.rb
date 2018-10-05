#!/opt/puppetlabs/puppet/bin/ruby
# shared library functions for albatrossflavour/os_patching
require 'open3'
require 'json'
module OsPatching
  module OsPatching
    @@warnings = {}
    @@log = nil
    BUFFER_SIZE = 4096

    def self.is_windows
      RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
    end

    def self.os_patching_dir
      if is_windows
        os_patching_dir = 'C:\ProgramData\os_patching'
      else
        os_patching_dir = '/var/cache/os_patching'
      end

      os_patching_dir
    end

    def self.chunk_updates
      updatelist = []
      updatefile = File.join(os_patching_dir,'package_updates')
      if File.file?(updatefile)
        if (Time.now - File.mtime(updatefile)) / (24 * 3600) > 10
          @@warnings['update_file_time'] = 'Update file has not been updated in 10 days'
        end

        updates = File.open(updatefile, 'r').read
        updates.each_line do |line|
          next unless line =~ /[A-Za-z0-9]+/
          next if line.match(/^#|^$/)
          line.sub! 'Title : ', ''
          updatelist.push line.chomp
        end
      else
        @@warnings['update_file'] = "Update file not found reading #{updatefile}, update information invalid"
      end

      updatelist
    end

    def self.chunk_secupdates
      secupdatelist = []
      secupdatefile = File.join(os_patching_dir, '/security_package_updates')
      if File.file?(secupdatefile)
        if (Time.now - File.mtime(secupdatefile)) / (24 * 3600) > 10
          @@warnings['sec_update_file_time'] = 'Security update file has not been updated in 10 days'
        end
        secupdates = File.open(secupdatefile, 'r').read
        secupdates.each_line do |line|
          next if line.empty?
          next if line.match(/^#|^$/)
          secupdatelist.push line.chomp
        end
      else
        @@warnings['security_update_file'] = "Security update file not found at #{secupdatefile}, update information invalid"
      end

      secupdatelist
    end

    def self.chunk_blackouts
      data = {}
      arraydata = {}
      data['blocked'] = false
      data['blocked_reasons'] = []
      blackoutfile = os_patching_dir + '/blackout_windows'
      if File.file?(blackoutfile)
        blackouts = File.open(blackoutfile, 'r').read
        blackouts.each_line do |line|
          next if line.empty?
          next if line.match(/^#|^$/)
          matchdata = line.match(/^([\w ]*),(\d{,4}-\d{1,2}-\d{1,2}T\d{,2}:\d{,2}:\d{,2}\+\d{,2}:\d{,2}),(\d{,4}-\d{1,2}-\d{1,2}T\d{,2}:\d{,2}:\d{,2}[-\+]\d{,2}:\d{,2})$/)
          if matchdata
            arraydata[matchdata[1]] = {} unless arraydata[matchdata[1]]
            if matchdata[2] > matchdata[3]
              arraydata[matchdata[1]]['start'] = 'Start date after end date'
              arraydata[matchdata[1]]['end'] = 'Start date after end date'
              @@warnings['blackouts'] = matchdata[0] + ' : Start data after end date'
            else
              arraydata[matchdata[1]]['start'] = matchdata[2]
              arraydata[matchdata[1]]['end'] = matchdata[3]
            end

            if (Time.parse(matchdata[2])..Time.parse(matchdata[3])).cover?(Time.now)
              data['blocked'] = true
              data['blocked_reasons'].push matchdata[1]
            end
          else
            @@warnings['blackouts'] = "Invalid blackout entry : #{line}"
            data['blocked'] = true
            data['blocked_reasons'].push "Invalid blackout entry : #{line}"
          end
        end
      end
      data['blackouts'] = arraydata
      data
    end

    # Are there any pinned packages in yum?
    def self.chunk_pinned
      pinnedpkgs = []
      pinnedpackagefile = '/etc/yum/pluginconf.d/versionlock.list'
      if File.file?(pinnedpackagefile)
        pinnedfile = File.open(pinnedpackagefile, 'r').read
        pinnedfile.each_line do |line|
          matchdata = line.match(/^[0-9]:(.*)/)
          if matchdata
            pinnedpkgs.push matchdata[1]
          end
        end
      end
      pinnedpkgs
    end

    # History info
    def self.chunk_history
      data = {}
      patchhistoryfile = File.join(os_patching_dir, '/run_history')
      data['last_run'] = {}
      if File.file?(patchhistoryfile)
        historyfile = File.open(patchhistoryfile, 'r').to_a
        line = historyfile.last.chomp
        matchdata = line.split('|')
        if matchdata[1]
          data['date'] = matchdata[0]
          data['message'] = matchdata[1]
          data['return_code'] = matchdata[2]
          data['post_reboot'] = matchdata[3]
          data['security_only'] = matchdata[4]
          data['job_id'] = matchdata[5]
        end
      end
      data
    end

    # Patch window
    def self.chunk_patchwindow
      patchwindowfile = File.join(os_patching_dir, '/patch_window')
      value = ''
      if File.file?(patchwindowfile)
        patchwindow = File.open(patchwindowfile, 'r').to_a
        line = patchwindow.last
        matchdata = line.match(/^(.*)$/)
        if matchdata[0]
          value = matchdata[0]
        end
      end

      value
    end

    # Reboot override
    def self.chunk_reboot_override
      rebootfile = File.join(os_patching_dir, '/reboot_override')
      if File.file?(rebootfile)
        rebootoverride = File.open(rebootfile, 'r').to_a
        value = case rebootoverride.last
                                  when /^always$/
                                    'always'
                                  when /^[Tt]rue$/
                                    'always'
                                  when /^[Ff]alse$/
                                    'never'
                                  when /^never$/
                                    'never'
                                  when /^patched$/
                                    'patched'
                                  when /^smart$/
                                    'smart'
                                  else
                                    'default'
                                  end
      else
        value = 'default'
      end
      value
    end

    # Reboot or restarts required?
    def self.chunk_reboot_required
      data = {}
      reboot_required_file = File.join(os_patching_dir, '/reboot_required')
      if File.file?(reboot_required_file)
        if (Time.now - File.mtime(reboot_required_file)) / (24 * 3600) > 10
          @@warnings['reboot_required_file_time'] = 'Reboot required file has not been updated in 10 days'
        end
        reboot_required_fh = File.open(reboot_required_file, 'r').to_a
        data['reboot_required'] = case reboot_required_fh.last
                                             when /^[Tt]rue$/
                                               true
                                             when /^[Ff]alse$/
                                               false
                                             else
                                               ''
                                             end
      else
        data['reboot_required'] = 'unknown'
      end
      app_restart_file = File.join(os_patching_dir,'/apps_to_restart')
      if File.file?(app_restart_file)
        app_restart_fh = File.open(app_restart_file, 'r').to_a
        data['apps_needing_restart'] = {}
        app_restart_fh.each do |line|
          line.chomp!
          key_value = line.split(' : ')
          data['apps_needing_restart'][key_value[0]] = key_value[1]
        end
        data['app_restart_required'] = if data['apps_needing_restart'].empty?
                                                    false
                                                  else
                                                    true
                                                  end
      end
      data
    end

    def self.chunk_warnings
      data = {}
      data['warnings'] = @@warnings
      data
    end

    # Function to write out the history file after patching
    def self.history(data)
      historyfile = '/var/cache/os_patching/run_history'
      open(historyfile, 'a') do |f|
        f.puts "#{data[:start_time]}|#{data[:message]}|#{data[:return]}|#{data[:reboot]}|#{data[:security]}|#{data[:job_id]}"
      end
    end

    # Default output function
    def self.output(payload)
      payload[:end_time] = Time.now.iso8601
      puts JSON.pretty_generate(payload)
      history(payload)
    end


    # Error output function
    def self.err(code, kind, message, starttime)
      get_logger.error "#{code} error mode"
      exitcode = code.to_s.split.last
      json = {
        _error: {
          msg: "Task exited : #{exitcode}\n#{message}",
          kind: kind,
          details: {exitcode: exitcode},
          start_time: starttime,
          end_time: Time.now.iso8601,
        },
      }

      puts JSON.pretty_generate(json)
      shortmsg = message.split("\n").first.chomp if message.split("\n").any?
      history(
        start_time: starttime,
        message: shortmsg,
        return: exitcode,
        reboot: '',
        security: '',
        job_id: '',
      )
      get_logger.error "ERROR : #{kind} : #{exitcode} : #{message}"
      exit(exitcode.to_i)
    end

    # Run a command and kill it if it takes to too long
    #
    # @return status code, output (array of string)
    def self.run_with_timeout(command, timeout=10, tick=2)
      output = ''
      @@log.debug "Running command: #{command}"
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
        status = if thread
                   thread.value.exitstatus
                 else
                   255
                 end
      end
      return status, output
    end

    # # facter -p os_patching
    # {
    #   package_update_count => 0,
    #   package_updates => [],
    #   security_package_updates => [],
    #   security_package_update_count => 0,
    #   blocked => false,
    #   blocked_reasons => [],
    #   blackouts => {},
    #   patch_window = 'Week3',
    #   pinned_packages => [],
    #   last_run => {
    #     date => "2018-08-07T21:55:20+10:00",
    #     message => "Patching complete",
    #     return_code => "Success",
    #     post_reboot => "false",
    #     security_only => "false",
    #     job_id => "60"
    #   }
    #   reboots => {
    #     reboot_required => false,
    #     apps_needing_restart => { },
    #     app_restart_required => false
    #   }
    # }
    def self.fact
      updatelist    = chunk_updates
      secupdatelist = chunk_secupdates
      blackouts     = chunk_blackouts
      reboots       = chunk_reboot_required
      # Facter Ruby API always uses strings for the keys of structured facts...
      {
        'package_updates'               => updatelist,
        'package_update_count'          => updatelist.size,
        'security_package_updates'      => secupdatelist,
        'security_package_update_count' => secupdatelist.count,
        'blocked'                       => blackouts['blocked'],
        'blocked_reasons'               => blackouts['blocked_reasons'],
        'blackouts'                     => blackouts['blackouts'],
        'pinned_packages'               => chunk_pinned,
        'last_run'                      => chunk_history,
        'patch_window'                  => chunk_patchwindow,
        'reboot_override'               => chunk_reboot_override,
        'warnings'                      => chunk_warnings,
        'reboots'                       => {
          'reboot_required'      => reboots['reboot_required'],
          'app_restart_required' => reboots['app_restart_required'],
          'apps_needing_restart' => reboots['apps_needing_restart'],
        },
      }
    end

    # Configure and return a logger instance if there isn't one already. We will
    # parse debug mode from the params hash if we can, otherwise we fallback to
    # the syslog logger to prevent erroring (eg if task invoked with invalid
    # JSON)
    def self.get_logger(params=nil)
      if @@log.nil?
        if params && params.key?('debug')
          @@log = Logger.new(STDOUT)
          @@log.level = Logger::DEBUG
        else
          @@log = Syslog::Logger.new 'os_patching'
        end
      end

      @@log
    end

    def self.get_params(starttime)
      begin
        raw = STDIN.read
        params = JSON.parse(raw)
        get_logger(params)
      rescue JSON::ParserError
        err(400,"os_patching/input", "Invalid JSON received: '#{raw}'", starttime)
      end

      params
    end

    def self.clean_cache(starttime, os_family)
      clean_cache = if os_family == 'RedHat'
                      'yum clean all'
                    elsif os_family == 'Debian'
                      'apt-get update'
                    end

      # Clean that cache!
      status, stderrout = run_with_timeout(clean_cache)
      err(status, 'os_patching/clean_cache', stderrout, starttime) if status != 0

      [status, stderrout]
    end

    def self.refresh_facts(starttime)
      fact_generation = '/usr/local/bin/os_patching_fact_generation.sh'
      unless File.exist? fact_generation
        err(
          255,
          "os_patching/#{fact_generation}",
          "#{fact_generation} does not exist, declare os_patching and run Puppet first",
          starttime,
        )
      end
      status, _fact_out = run_with_timeout(fact_generation)
      err(status, 'os_patching/fact_refresh', _fact_out, starttime) if status != 0
    end

    def self.supported_platform(starttime, os_family)
      if is_windows
        err(200, 'os_patching/unsupported_os', 'Cannot run os_patching::clean_cache on Windows', starttime)
      end

      # Check we are on a supported platform
      unless os_family == 'RedHat' || os_family == 'Debian'
        err(200, 'os_patching/unsupported_os', "Unsupported OS family: #{os_family}", starttime)
      end
    end

  end
end
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
