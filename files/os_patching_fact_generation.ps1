$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8';Import-Module PSWindowsUpdate; Get-WUList -WindowsUpdate | Format-List -Property Title > C:\ProgramData\PuppetLabs\puppet\cache\package_updates
