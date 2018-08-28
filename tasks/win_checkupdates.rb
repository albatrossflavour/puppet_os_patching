#!/opt/puppetlabs/puppet/bin/ruby
require 'open3'
require 'json'
require 'win32/registry'

# rubocop:disable Lint/UselessAssignment
params = JSON.parse(STDIN.read)
# rubocop:enable Lint/UselessAssignment

def check_ps_module
  # Determine if the PSWindowsUpdate module is installed on disk and retrieve if it is not
  # Get registry setting for Powershell module directory
  reg_key = Win32::Registry::HKEY_LOCAL_MACHINE.open('System\CurrentControlSet\Control\Session Manager\Environment')
  module_path = (reg_key['PSModulePath']).split(';') || nil
  if module_path.nil? || module_path.empty?
    puts 'No module path for Powershell was found in the registry'
    exit 1
  end
  # Determine if the PSWindowsUpdate module is installed on disk and retrieve if it is not
  unless Dir.exist?("#{module_path[0]}\\PSWindowsUpdate")
    case params['module_source']
    when 'PSGallery'
      url = 'https://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc/file/41459/47/PSWindowsUpdate.zip'
    when 'URL'
      if params['module_url'].nil? || params['module_url'].empty?
        puts '`module_url` is required if URL method of retrieving the PSWindowsUpdate module is selected'
        exit 1
      else
        url = params['module_url']
      end
    end
    download_cmd = "powershell -command \"[Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}; $webClient = New-Object System.Net.WebClient; $webClient.DownloadFile('#{url}','#{ENV['TEMP']}\\PSWindowsUpdate.zip')\"" # rubocop:disable Metrics/LineLength
    _stdout, _stderr, status = Open3.capture3(download_cmd)
    if status != 0
      puts 'Failed to download ZIP file'
      exit 1
    end
    # Unzip the file
    unzip_cmd = "powershell -command \"Expand-Archive -LiteralPath '#{ENV['TEMP']}\\PSWindowsUpdate.zip' -DestinationPath '#{module_path[0]}'\""
    stdout, _stderr, status = Open3.capture3(unzip_cmd)
    if status != 0
      puts "Failed to uncompress PSWindowsUpdate.zip #{stdout}"
      exit 1
    end
  end
rescue StandardError => e
  raise Error, "Experienced an error: #{e.message}"
end

begin
  # Find if we are using WSUS or Windows Update
  manager_cmd = "powershell -command \"Import-Module PSWindowsUpdate; Get-WUServiceManager | Where-Object {$_.IsManaged -eq 'true'} | foreach {$_.ServiceID}\""
  stdout, stderr, status = Open3.capture3(manager_cmd)
  raise 'Cannot get Windows Update configurations', stderr if status != 0
  # Determine which service is enable can use that to check for patches and updates
  if stdout
    case stdout.strip
    when '3da21691-e39d-4da6-8a4b-b43877bcb1b7'
      cmd_string = 'powershell -command "Import-Module PSWindowsUpdate; Get-WUList | Format-List -Property KB,Size,Title"'
    when '9482f4b4-e343-43b6-b170-9a65bc822c77'
      cmd_string = 'powershell -command "Import-Module PSWindowsUpdate; Get-WUList -WindowsUpdate | Format-List -Property KB,Size,Title"'
    when '7971f918-a847-4430-9279-4a52d1efe18d'
      cmd_string = 'powershell -command "Import-Module PSWindowsUpdate; Get-WUList -MicrosoftUpdate | Format-List -Property KB,Size,Title"'
    else
      puts 'No Update Services configured'
      exit 0
    end
    # run the relevant command
    stdout, _stderr, _status = Open3.capture3(cmd_string)
    if stdout && !stdout.nil? && !stdout.empty?
      puts stdout.strip
    else
      puts 'No patches or updates found'
    end
    exit 0
  end
rescue StandardError => e
  raise Error, "There was a problem #{e}"
end
