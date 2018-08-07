Facter.add('os_patching', :type => :aggregate) do
  confine :kernel => 'Linux'

  require 'time'
  now = Time.now.iso8601

  chunk(:updates) do
    data = {}
    updatelist = []
    updatefile = '/etc/os_patching/package_updates'
    if File.file?(updatefile)
      updates = File.open(updatefile, 'r').read
      updates.each_line do |line|
        next if line.empty?
        next if line.include? '^#'
        updatelist.push line.chomp
      end
    end
    data['package_updates'] = updatelist
    data['package_update_count'] = updatelist.count
    data
  end

  chunk(:secupdates) do
    data = {}
    secupdatelist = []
    secupdatefile = '/etc/os_patching/security_package_updates'
    if File.file?(secupdatefile)
      secupdates = File.open(secupdatefile, 'r').read
      secupdates.each_line do |line|
        next if line.empty?
        next if line.include? '^#'
        secupdatelist.push line.chomp
      end
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
    blackoutfile = '/etc/os_patching/blackout_windows'
    if File.file?(blackoutfile)
      blackouts = File.open(blackoutfile, 'r').read
      blackouts.each_line do |line|
        matchdata = line.match(/^([\w ]*),([\d:T\-\\+]*),([\d:T\-\\+]*)$/)
        next unless matchdata
        unless arraydata[matchdata[1]]
          arraydata[matchdata[1]] = {}
          if matchdata[2] > matchdata[3]
            arraydata[matchdata[1]]['start'] = 'Start date after end date'
            arraydata[matchdata[1]]['end'] = 'Start date after end date'
          else
            arraydata[matchdata[1]]['start'] = matchdata[2]
            arraydata[matchdata[1]]['end'] = matchdata[3]
          end
        end

        if (matchdata[2]..matchdata[3]).cover?(now)
          data['blocked'] = true
          data['blocked_reasons'].push matchdata[1]
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
    data['pinned_packages'] = pinnedpkgs
    data
  end

  # History info
  chunk(:history) do
    data = {}
    patchhistoryfile = '/etc/os_patching/run_history'
    if File.file?(patchhistoryfile)
      historyfile = File.open(patchhistoryfile, 'r').to_a
      data['last_run'] = {}
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
      data
    end
  end

  # Patch window
  chunk(:patch_window) do
    data = {}
    patchwindowfile = '/etc/os_patching/patch_window'
    if File.file?(patchwindowfile)
      patchwindow = File.open(patchwindowfile, 'r').to_a
      line = patchwindow.last
      matchdata = line.match(/^(.*)$/)
      if matchdata[0]
        data['patch_window'] = matchdata[0]
      end
    end
    data
  end

  # Reboot override
  chunk(:reboot_override) do
    rebootfile = '/etc/os_patching/reboot_override'
    if File.file?(rebootfile)
      rebootoverride = File.open(rebootfile, 'r').to_a
      data = {}
      data['reboot_override'] = case rebootoverride.last
                                when /^[Tt]rue$/
                                  true
                                when /^[Ff]alse$/
                                  false
                                else
                                  ''
                                end
      end
    data
  end
end
