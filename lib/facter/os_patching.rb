# Ensure that this fact does not try to be loaded
# on old (pre v.2) versions of facter as it uses
# aggregate facts
if Facter.value(:facterversion).split('.')[0].to_i < 2
  Facter.add('os_patching') do
    setcode do
      'not valid on legacy facter versions'
    end
  end
else
  Facter.add('os_patching', :type => :aggregate) do
    confine { Facter.value(:kernel) == 'windows' || Facter.value(:kernel) == 'Linux' }
    require 'time'
    now = Time.now.iso8601
    warnings = {}

    if Facter.value(:kernel) == 'Linux'
      os_patching_dir = '/var/cache/os_patching'
    elsif Facter.value(:kernel) == 'windows'
      os_patching_dir = 'C:\ProgramData\os_patching'
    end

    chunk(:updates) do
      data = {}
      updatelist = []
      updatefile = os_patching_dir + '/package_updates'
      if File.file?(updatefile)
        if (Time.now - File.mtime(updatefile)) / (24 * 3600) > 10
          warnings['update_file_time'] = 'Update file has not been updated in 10 days'
        end

        updates = File.open(updatefile, 'r').read
        updates.each_line do |line|
          next unless line =~ /[A-Za-z0-9]+/
          next if line =~ /^#|^$/
          line.sub! 'Title : ', ''
          updatelist.push line.chomp
        end
      else
        warnings['update_file'] = 'Update file not found, update information invalid'
      end
      data['package_updates'] = updatelist
      data['package_update_count'] = updatelist.count
      data
    end

    chunk(:kb_updates) do
      data = {}
      kblist = []
      kbfile = os_patching_dir + '/missing_update_kbs'
      if File.file?(kbfile) and not File.zero?(kbfile)
        kbs = File.open(kbfile, 'r').read
        kbs.each_line do |line|
          kblist.push line.chomp
        end
      end
      data['missing_update_kbs'] = kblist
      data
    end

    chunk(:secupdates) do
      data = {}
      secupdatelist = []
      secupdatefile = os_patching_dir + '/security_package_updates'
      if File.file?(secupdatefile)
        if (Time.now - File.mtime(secupdatefile)) / (24 * 3600) > 10
          warnings['sec_update_file_time'] = 'Security update file has not been updated in 10 days'
        end
        secupdates = File.open(secupdatefile, 'r').read
        secupdates.each_line do |line|
          next if line.empty?
          next if line =~ /^#|^$/
          secupdatelist.push line.chomp
        end
      else
        warnings['security_update_file'] = 'Security update file not found, update information invalid'
      end
      data['security_package_updates'] = secupdatelist
      data['security_package_update_count'] = secupdatelist.count
      data
    end

    chunk(:blackouts) do
      data = {}
      arraydata = {}
      data['blocked'] = false
      data['blocked_reasons'] = {}
      data['blocked_reasons'] = []
      blackoutfile = os_patching_dir + '/blackout_windows'
      if File.file?(blackoutfile)
        blackouts = File.open(blackoutfile, 'r').read
        blackouts.each_line do |line|
          next if line.empty?
          next if line =~ /^#|^$/
          matchdata = line.match(/^([\w ]*),(\d{,4}-\d{1,2}-\d{1,2}T\d{,2}:\d{,2}:\d{,2}\+\d{,2}:\d{,2}),(\d{,4}-\d{1,2}-\d{1,2}T\d{,2}:\d{,2}:\d{,2}[-\+]\d{,2}:\d{,2})$/)
          if matchdata
            # rubocop:disable Metrics/BlockNesting
            arraydata[matchdata[1]] = {} unless arraydata[matchdata[1]]
            if matchdata[2] > matchdata[3]
              arraydata[matchdata[1]]['start'] = 'Start date after end date'
              arraydata[matchdata[1]]['end'] = 'Start date after end date'
              warnings['blackouts'] = matchdata[0] + ' : Start data after end date'
            else
              arraydata[matchdata[1]]['start'] = matchdata[2]
              arraydata[matchdata[1]]['end'] = matchdata[3]
            end

            if (matchdata[2]..matchdata[3]).cover?(now)
              data['blocked'] = true
              data['blocked_reasons'].push matchdata[1]
            end
            # rubocop:enable Metrics/BlockNesting
          else
            warnings['blackouts'] = "Invalid blackout entry : #{line}"
            data['blocked'] = true
            data['blocked_reasons'].push "Invalid blackout entry : #{line}"
          end
        end
      end
      data['blackouts'] = arraydata
      data
    end

    # Are there any pinned packages in yum?
    chunk(:pinned) do
      data = {}
      pinnedpkgs = []
      mismatchpinnedpackagefile = os_patching_dir + '/mismatched_version_locked_packages'
      pinnedpackagefile = os_patching_dir + '/os_version_locked_packages'
      if File.file?(pinnedpackagefile)
        pinnedfile = File.open(pinnedpackagefile, 'r').read.chomp
        pinnedfile.each_line do |line|
          pinnedpkgs.push line.chomp
        end
      end
      if File.file?(mismatchpinnedpackagefile) and not File.zero?(mismatchpinnedpackagefile)
        warnings['packages_version_locked_in_catalog_but_not_on_os'] = []
        mismatchfile = File.open(mismatchpinnedpackagefile, 'r').read
        mismatchfile.each_line do |line|
          warnings['packages_version_locked_in_catalog_but_not_on_os'].push line.chomp
        end
      end
      data['pinned_packages'] = pinnedpkgs
      data
    end

    # History info
    chunk(:history) do
      data = {}
      patchhistoryfile = os_patching_dir + '/run_history'
      data['last_run'] = {}
      if File.file?(patchhistoryfile)
        historyfile = File.open(patchhistoryfile, 'r').to_a
        line = historyfile.last.chomp
        matchdata = line.split('|')
        if matchdata[1]
          data['last_run']['date'] = matchdata[0]
          data['last_run']['message'] = matchdata[1]
          data['last_run']['return_code'] = matchdata[2]
          data['last_run']['post_reboot'] = matchdata[3]
          data['last_run']['security_only'] = matchdata[4]
          data['last_run']['job_id'] = matchdata[5]
        end
      end
      data
    end

    # Patch window
    chunk(:patch_window) do
      data = {}
      patchwindowfile = os_patching_dir + '/patch_window'
      if File.file?(patchwindowfile)
        patchwindow = File.open(patchwindowfile, 'r').to_a
        line = patchwindow.last
        matchdata = line.match(/^(.*)$/)
        if matchdata[0]
          data['patch_window'] = matchdata[0]
        end
      else
        data['patch_window'] = ''
      end
      data
    end

    # Reboot override
    chunk(:reboot_override) do
      rebootfile = os_patching_dir + '/reboot_override'
      data = {}
      if File.file?(rebootfile)
        rebootoverride = File.open(rebootfile, 'r').to_a
        data['reboot_override'] = case rebootoverride.last
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
        data['reboot_override'] = 'default'
      end
      data
    end

    # Reboot or restarts required?
    chunk(:reboot_required) do
      data = {}
      data['reboots'] = {}
      reboot_required_file = os_patching_dir + '/reboot_required'
      if File.file?(reboot_required_file)
        if (Time.now - File.mtime(reboot_required_file)) / (24 * 3600) > 10
          warnings['reboot_required_file_time'] = 'Reboot required file has not been updated in 10 days'
        end
        reboot_required_fh = File.open(reboot_required_file, 'r').to_a
        data['reboots']['reboot_required'] = case reboot_required_fh.last
                                             when /^[Tt]rue$/
                                               true
                                             when /^[Ff]alse$/
                                               false
                                             else
                                               ''
                                             end
      else
        data['reboots']['reboot_required'] = 'unknown'
      end
      app_restart_file = os_patching_dir + '/apps_to_restart'
      if File.file?(app_restart_file)
        app_restart_fh = File.open(app_restart_file, 'r').to_a
        data['reboots']['apps_needing_restart'] = {}
        app_restart_fh.each do |line|
          line.chomp!
          key_value = line.split(' : ')
          data['reboots']['apps_needing_restart'][key_value[0]] = key_value[1]
        end
        data['reboots']['app_restart_required'] = if data['reboots']['apps_needing_restart'].empty?
                                                    false
                                                  else
                                                    true
                                                  end
      end
      data
    end
    chunk(:warnings) do
      data = {}
      data['warnings'] = warnings
      data
    end
  end
end
