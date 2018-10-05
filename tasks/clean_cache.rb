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

require 'facter'
require 'rbconfig'
require 'pp'
require 'open3'
require 'json'
require 'syslog/logger'
require 'time'
require 'timeout'

$stdout.sync = true
starttime = Time.now.iso8601



# Cache the facts
facts = {
  values: {
    os: Facter.value(:os),
  }
}


OsPatching::OsPatching.supported_platform(starttime, facts[:values][:os]['family'])

# params is used to activate debug logging
params = OsPatching::OsPatching.get_params(starttime)
log = OsPatching::OsPatching.get_logger(params)
log.debug("facts: #{facts.pretty_print_inspect}")

status, stderrout = OsPatching::OsPatching.clean_cache(starttime, facts[:values][:os]['family'])
OsPatching::OsPatching.output(
  return: status,
  message: 'Cache cleaned',
  debug: stderrout,
  start_time: starttime,
)
log.info 'Cache cleaned'
