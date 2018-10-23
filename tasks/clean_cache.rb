#!/opt/puppetlabs/puppet/bin/ruby

require 'open3'
require 'json'
require 'rbconfig'
require 'logger'
require 'syslog/logger'
require 'pp'

# namespace our shared library
# rubocop:disable Style/ClassVars, Performance/RedundantMatch,  Style/ClassAndModuleChildren
module OsPatching
  # shared library functions for albatrossflavour/os_patching
  module OsPatching
    @@warnings = {}
    @@log = nil
    @@testcase = nil
    BUFFER_SIZE = 4096
    SHORT_TIMEOUT = 10

    # Reset any module state (for testing)
    # @return nil
    def self.reset
      @@warnings = {}
      @@testcase = nil
    end

    # Test if task is running on windows or not
    # @return `true` if running on windows otherwise `false`
    def self.windows?
      RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
    end

    # Use data from a testcase instead of the real data (for testing)
    # @param dir Read testcase data from this directory when parsing facts
    # @return nil
    def self.use_testcase(dir)
      @@testcase = dir
    end

    # Determine the directory to read os_patching module state from. Data is
    # written by the puppet code _and_ the fact refresh script, when run.
    # @return Directory to read saved state from
    def self.os_patching_dir
      os_patching_dir = @@testcase || (windows? ? 'C:\ProgramData\os_patching' : '/var/cache/os_patching')

      os_patching_dir
    end

    # Read `package_updates` - the list of currently available updates and
    # return the cleaned-up contents. If errors are encountered on the way,
    # update warnings.
    #
    # This is used to populate the custom fact.
    #
    # @return Array of packages that are available for update
    def self.chunk_updates
      updatelist = []
      updatefile = File.join(os_patching_dir, 'package_updates')
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

    # Read `security_package_updates` - the list of currently available security
    # updates and return the cleaned-up contents. If errors are encountered on
    # the way, update warnings
    #
    # This is used to populate the custom fact.
    #
    # @return Array of packages that are available for update (security only)
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

    # Parse the `blackout_windows` file
    #
    # This is used to populate the custom fact.
    #
    # @return hash of parsed blackout windows:
    # ```
    #   'blocked'         => true|false # whether updates are currently blocked
    #   'blocked_reasons' => []         # Array of reasons (string) or empty array
    #   'blackouts'       => {}         # Hash of active blackouts or empty hash
    # ```
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

    # Are there any pinned packages in yum according to `versionlock.list`?
    #
    # This is used to populate the custom fact.
    #
    # @return Array of pinned packages or empty array
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

    # Expose any os_patching history data from `run_history`
    #
    # This is used to populate the custom fact.
    #
    # @return Hash of historical run data with keys:
    # ```
    # 'date'          => _timestamp in ISO format_
    # 'message'       => _human readable message_
    # 'return_code'   => _human readable return code eg `Success`_
    # 'post_reboot'   => _what was done with reboots_
    # 'security_only' => _was this a security only update?_
    # 'job_id'        => _ID from yum_
    # ```
    def self.chunk_history
      data = {}
      patchhistoryfile = File.join(os_patching_dir, '/run_history')
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

    # Read the Patch Window value from `patch_window`. Patch window is used to
    # identify groups of machines so they can be targed for updates en-mass.
    #
    # This is used to populate the custom fact.
    #
    # @return The patch window that applies to this node
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

    # Read the how reboots should be handled from `reboot_override`.
    #
    # This is used to populate the custom fact.
    #
    # @return The policy to use for rebooting after updates. One of: `always`,
    # `never`, `patched`, `smart`, `default`
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

    # Read if reboot or restarts required from `reboot_required` and
    # `apps_needing_restart`
    #
    # This is used to populate the custom fact.
    #
    # @return hash with keys:
    # ```
    # 'reboot_required'      => _whether a reboot is required_
    # 'apps_needing_restart' => _Hash of apps to restart_
    # 'app_restart_required' => _Whether any apps need restarting_
    # ```
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
      app_restart_file = File.join(os_patching_dir, '/apps_to_restart')
      if File.file?(app_restart_file)
        app_restart_fh = File.open(app_restart_file, 'r').to_a
        data['apps_needing_restart'] = {}
        app_restart_fh.each do |line|
          line.chomp!
          key_value = line.split(' : ')
          data['apps_needing_restart'][key_value[0]] = key_value[1]
        end
        data['app_restart_required'] = data['apps_needing_restart'].any?
      end
      data
    end

    # Warnings are collected to the module-level variable `@@warnings` and are
    # exposed through this accessor
    #
    # This is used to populate the custom fact.
    #
    # @return Hash of collected warning messages or empty Hash
    def self.chunk_warnings
      @@warnings
    end

    # After each run, we write out what actions were performed to the
    # `run_history` file.
    # @param data Hash of data to write to the history file:
    # * start time
    # * message
    # * return code
    # * reboot info
    # * security info
    # * job id
    # @return nil
    def self.history(data)
      historyfile = File.join(os_patching_dir, 'run_history')
      open(historyfile, 'a') do |f|
        f.puts "#{data[:start_time]}|#{data[:message]}|#{data[:return]}|#{data[:reboot]}|#{data[:security]}|#{data[:job_id]}"
      end
    end

    # Print output message
    #
    # Convert payload into JSON data, adding a `end_time` time stamp, then print
    # it to STDOUT. After doing this, save the payload history.
    # @param payload Each key will be converted to JSON for you, `end_time` will
    #   be added automatically and contains the current time
    # @return nil
    def self.output(payload)
      payload[:end_time] = Time.now.iso8601
      puts JSON.pretty_generate(payload)
      history(payload)
    end

    # Print error message
    # Convert parameters into JSON data, adding a `end_time` time stamp, then
    # log it to the error and print to STDOUT. Log the same error message to
    # history and then fail the task by exiting with non-zero status
    # @param code Error code (integer)
    # @param kind Short error message
    # @param message Error message from system/full error message
    # @param starttime Timestamp task started running
    # @return nil
    def self.err(code, kind, message, starttime)
      get_logger.error "#{code} error mode"
      exitcode = code.to_s.split.last
      json = {
        _error: {
          msg: "Task exited : #{exitcode}\n#{message}",
          kind: kind,
          details: { exitcode: exitcode },
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
    # @param command Command to run
    # @param timeout Timeout in seconds. Command will be killed if timeout
    #   exceeded
    # @param tick Timeout for `Kernel.select`
    # @return status code, output (array of string)
    def self.run_with_timeout(command, timeout = SHORT_TIMEOUT, tick = 2)
      output = ''
      @@log.debug "Running command (timeout=#{timeout}): #{command}"
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
      [status, output]
    end

    # Build the structured fact and return it.
    #
    # @return Hash representing the `os_patching` custom fact. Example format:
    # ```
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
    # ```
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
    # @param params Hash of parsed parameters that were passed to the task. We
    #   use these to see if the `debug` parameter was present. If so, we switch
    #   to the STDOUT logger and set the log level to debug
    # @return logger instance (syslog or STDOUT)
    def self.get_logger(params = nil)
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

    # Parse any parameters passed in from STDIN. STDIN is expected to contain
    # parameters in JSON, as described by the task definitions. This data
    # normally originates from PE/tasks itself.
    #
    # @param starttime Timestamp that execution started at (for logging errors)
    # @return Hash of parameter data parsed from STDIN
    def self.get_params(starttime)
      begin
        raw = STDIN.read
        params = JSON.parse(raw)
        get_logger(params)
      rescue JSON::ParserError
        err(400, 'os_patching/input', "Invalid JSON received: '#{raw}'", starttime)
      end

      params
    end

    # Clean up the OS cache (`yum clean`/`apt-get clean`), then report status
    #
    # @param starttime Timestamp task started executing (for logging)
    # @param os_family OS We are running on, to pick the right clean command
    # @param timeout Timeout in seconds
    # @return Exit status and output (array of string)
    def self.clean_cache(starttime, os_family, timeout)
      clean_cache = if os_family == 'RedHat'
                      'yum clean all'
                    elsif os_family == 'Debian'
                      'apt-get update'
                    end

      # Clean that cache!
      status, stderrout = run_with_timeout(clean_cache, timeout)
      err(status, 'os_patching/clean_cache', stderrout, starttime) if status != 0

      [status, stderrout]
    end

    # (Re)run the fact generation script
    #
    # If the script is missing, we exit with error. Run the main puppet class to
    # fix this.
    #
    # @param starttime Timestamp task started running (for logging)
    # @param timeout How long to wait before killing the generation script
    #   (seconds)
    # @return nil
    def self.refresh_facts(starttime, timeout)
      fact_generation = '/usr/local/bin/os_patching_fact_generation.sh'
      unless File.exist? fact_generation
        err(
          255,
          "os_patching/#{fact_generation}",
          "#{fact_generation} does not exist, declare os_patching and run Puppet first",
          starttime,
        )
      end
      status, fact_out = run_with_timeout(fact_generation, timeout)
      err(status, 'os_patching/fact_refresh', fact_out, starttime) if status != 0

      fact_out
    end

    # Test if we are running on a supported platform or not. If platform is
    # unsupported we call `err()` which will end the task with an error
    #
    # @param starttime Timestamp task started running (for logging)
    # @param os_family Name of OS family we are running on to see if its
    #   supported
    # @return nil
    def self.supported_platform(starttime, os_family)
      if windows?
        err(200, 'os_patching/unsupported_os', 'Cannot run os_patching::clean_cache on Windows', starttime)
      end

      # Check we are on a supported platform
      err(200, 'os_patching/unsupported_os', "Unsupported OS family: #{os_family}", starttime) unless ['RedHat', 'Debian'].include? os_family
    end

    # parse the any user specified timeout or insert the default value. If user
    # supplies invalid timeout, then fail the task
    #
    # @param params Hash of parameters received by the task on STDIN as JSON
    # @param starttime Timestamp task started (for logging)
    # @return Timeout in seconds
    def self.get_timeout(params, starttime)
      if params['timeout']
        if params['timeout'] > 0
          timeout = params['timeout']
        else
          err('121', 'os_patching/timeout', "timeout set to #{params['timeout']} seconds - invalid", starttime)
        end
      else
        timeout = 3600
      end

      timeout
    end
  end
end
# rubocop:disable Layout/LeadingCommentSpace
#!/opt/puppetlabs/puppet/bin/ruby
require 'facter'
require 'time'

$stdout.sync = true
starttime = Time.now.iso8601

# Cache the facts
facts = {
  values: {
    os: Facter.value(:os),
  },
}

# fail on unsupported
OsPatching::OsPatching.supported_platform(starttime, facts[:values][:os]['family'])

# params is used to activate debug logging
params = OsPatching::OsPatching.get_params(starttime)
timeout = OsPatching::OsPatching.get_timeout(params, starttime)

log = OsPatching::OsPatching.get_logger(params)
log.debug("facts: #{facts.pretty_print_inspect}")

status, stderrout = OsPatching::OsPatching.clean_cache(starttime, facts[:values][:os]['family'], timeout)
OsPatching::OsPatching.output(
  return: status,
  message: 'Cache cleaned',
  debug: stderrout,
  start_time: starttime,
)
log.info 'Cache cleaned'
