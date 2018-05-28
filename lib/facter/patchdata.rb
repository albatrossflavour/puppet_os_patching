Facter.add(:patchdata, :type => :aggregate) do

  yumupdatefile = "/var/patching-data/cache.yum.cu"
  yumsecupdatefile = "/var/patching-data/cache.yum.scu"
  yumsecupdatecode = "/var/patching-data/cache.yum.scu.code"
  yumcvefile = "/var/patching-data/cache.yum.listsec"

  # Only run on Redhat/yum based servers
  confine :osfamily => "Redhat"

  chunk(:versioning) do
    data = {}
    data["version"] = {:version => "Patch data V1"}
    data
  end

  # Collect data for later processing
  compliance_secupdates = 0 # Count of security updates
  compliance_updates = 0 # Count of normal updates

  # Pull the data from the cache files, created by the cron script
  if File.file?(yumupdatefile)
    updates = File.open(yumupdatefile, "r").read # .strip
  end
  if File.file?(yumsecupdatefile)
    secupdates = File.open(yumsecupdatefile, "r").read # .strip
  end
  if File.file?(yumsecupdatecode)
    secupdatesexit = File.open(yumsecupdatecode, "r").read.strip.to_i
  end
  if File.file?(yumcvefile)
    cvedata = File.open(yumcvefile, "r").read # .strip
  end


  # Display CVE data
  # This includes all RHSA as well as bugfixes, so not completely CVE. But, this is
  # what we are most interested in. Arrange as a hash of priority with array of ids.
  chunk(:cvedata) do
    data = {}
    arraydata = {}
    if (cvedata)
      cvedata.each_line do |line|
        # RH-id priority pkg
        matchdata = line.match(/^(\S+)\s+(\S+)\s+(.*)/)
        if (matchdata)
          if (!arraydata[matchdata[2]])
            arraydata[matchdata[2]] = Array.new
          end
          arraydata[matchdata[2]].push matchdata[1]
        end
      end
      data['updateinfo'] = arraydata
      data
    end
  end

  chunk(:updatedata) do
    data = {}
    arraydata = {}
    pkgdata = {}
    if (secupdates)
      if (secupdatesexit == 100)
        secupdates.each_line do |line|
          matchdata = line.match(/^(\S+)\s+(\S+)\s+\S+.*$/)
          if (matchdata)
            pkgdata[matchdata[1]] = matchdata[2]
          end
        end
        arraydata['secupdatelist'] = pkgdata
      end
      compliance_secupdates = pkgdata.count # Collect for later compliance calculations
      arraydata['secnumupdates'] = compliance_secupdates
    end
    pkgdata = {}  # Clear hash for processing new list of packages
    if (updates)
      if (updatesexit == 100)
        updates.each_line do |line|
          matchdata = line.match(/^(\S+)\s+(\S+)\s+\S+.*$/)
          if (matchdata)
            pkgdata[matchdata[1]] = matchdata[2]
          end
        end
        arraydata['updatelist'] = pkgdata
      end
      compliance_updates = pkgdata.count # Collect for later compliance calculations
      arraydata['numupdates'] = compliance_updates
    end
    data['updates'] = arraydata
    data
  end
end
