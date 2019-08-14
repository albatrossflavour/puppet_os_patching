#Requires -Version 3.0

#
# Performs an update scan, and refreshes update related facts, for the puppet module os_patching.
# Developed by Nathan Giuliani (nathojg@gmail.com) and Tony Green
#
# Unlike the main os_patching_windows script, this code does not need to run as either a scheduled task or locally with invoke-command.
# This is because the Windows Update Scan API is available in a remote session, as long as the user has administrative rights.
# As a result this script is a little simpler than os_patching_windows.
#
# Changelog
#
# v1.0.0 - 2019/04/30
#  - Initial release. Was originally part of os_patching_windows, has been split to a separate fact generation script to more closely fit
#    the way the rest of the module functions.
#


<#
.SYNOPSIS
Performs an update scan, and refreshes update related facts, for the puppet module os_patching.

.DESCRIPTION
Performs an update scan, and refreshes update related facts, for the puppet module os_patching. This script is intended to be run as part of the os_patching module, however it will also function standalone.

.PARAMETER UpdateCriteria
Criteria used for update detection. This ultimately drives which updates will be installed. The detault is "IsInstalled=0 and IsHidden=0" which should be suitable in most cases, and relies on your upstream update approvals. Note that this is not validated, if the syntax is not validated the script will fail. See MSDN doco for valid syntax - https://docs.microsoft.com/en-us/windows/desktop/api/wuapi/nf-wuapi-iupdatesearcher-search.
#>

[CmdletBinding()]
param(
    [String]$UpdateCriteria = "IsInstalled=0 and IsHidden=0",

    # path to lock file
    # default to same one as os_patching_windows so this won't run at the same time
    [String]$LockFile = (Join-Path -Path ($env:programdata) -ChildPath "os_patching\os_patching_windows.lock"),

    # path to logs directory
    [String]$LogDir = (Join-Path -Path ($env:programdata) -ChildPath "os_patching"),

    # how long to retain log files
    [Int32]$LogFileRetainDays = 30
)

# strict mode
Set-StrictMode -Version 2

# clear any errors
$error.Clear()

# Set error action preference to stop. Trap ensures all errors are caught
$ErrorActionPreference = "stop"

# ------------------------------------------------------------------------------------------------------------------------
# Start main script functions
# ------------------------------------------------------------------------------------------------------------------------

function Save-LockFile {
    # start assuming it's not OK to save a lock file
    $lockFileOk = $false

    # check if it exists already
    if (Test-Path $LockFile) {
        Add-LogEntry -Output Verbose "Existing lock file found."
        # if it does exist, check if there is a PID in it
        $lockFileContent = Get-content $lockfile

        if (@($lockFileContent).count -gt 1) {
            # more than one line in lock file. this shouldn't be possible
            Throw "Error - more than one line in lock file."
        }
        else {
            # only one line in lock file
            # get process matching this PID
            $process = Get-Process | Where-Object { $_.Id -eq $lockFileContent }

            # if process exists
            if ($process) {
                # Check the path of the process matching PID in the lock file
                if ($process.path -match "powershell.exe") {
                    # most likely is another copy of this script
                    Throw "Lock file found, it appears PID $($process.id) is another copy of os_patching_fact_generation or os_patching_windows. Exiting."
                }
            }
            else {
                Add-LogEntry -Output Verbose "No process found matching the PID in lock file"
                # no process found matching the PID in the lock file
                # remove it and continue
                Remove-LockFile
                $lockFileOk = $true
            }
        }
    }
    else {
        # lock file doesn't exist
        $lockFileOk = $true
    }

    if ($lockFileOk) {
        # if it isn't, put this execution's PID in the lock file
        try {
            Add-LogEntry -Output Verbose "Saving lock file"
            $PID | Out-File $LockFile -Force
            # return true
            $true
        }
        catch {
            Throw "Error saving lockfile."
        }
    }
}

function Remove-LockFile {
    # remove the lock file, if it exists
    if (Test-Path $LockFile) {
        Try {
            Add-LogEntry -Output Verbose "Removing lock file"
            Remove-Item $LockFile -Force -Confirm:$false
        }
        catch {
            Throw "Error removing existing lockfile."
        }
    }
}

function Invoke-CleanLogFile {
    Param (
        [Parameter(Mandatory = $true)]
        $LogFileFilter
    )
    # clean up logs older than $LogFileRetainDays days old
    Get-ChildItem $LogDir -Filter $LogFileFilter | Where-Object { $_.CreationTime -lt ([datetime]::Now.AddDays(-$LogFileRetainDays)) } | ForEach-Object {
        Add-LogEntry "Cleaning old log file $($_.BaseName)" -Output Verbose
        $_ | Remove-Item -Force -Confirm:$false
    }
}

function Add-LogEntry {
    # function to add a log entry for our script block
    # takes the input and adds to a script-scope log variable, which is intended to
    # be an array
    # inputs - log entry/entries either on pipeline, as a string or array of strings
    # outputs - none

    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline, Mandatory)]
        [string[]]$logEntry,

        [ValidateSet('info', 'error', 'warning', 'verbose', 'debug')]
        [string]$Output = 'info',

        [switch]$FileOnly
    )
    begin { }
    process {
        foreach ($entry in $logEntry) {
            # if logging an error, we don't want multiple write-errors done
            # as each one incudes a line reference and it gets messy
            # so just output the entire object before we split
            if ($Output -eq "error") {
                Write-Error ($logEntry -join '`n') -ErrorAction Continue # so we don't exit here
            }

            $thisEntry = $entry.split("`n")

            foreach ($line in $thisEntry) {

                if (-not $FileOnly) {
                    Switch ($Output) {
                        'info' {
                            Write-Host $line
                        }
                        'error' {
                            # sent to console above
                        }
                        'warning' {
                            Write-Warning $line
                        }
                        'verbose' {
                            Write-Verbose $line
                        }
                        'debug' {
                            Write-Debug $line
                        }
                    }

                    # prefix with date/time, pid, and output type
                    $thisEntry = "{0:yyyy-MM-dd HH:mm:ss} {1,-6} [{2,-7}] {3}" -f (Get-Date), $PID, $Output.toupper(), $line
                }
                else {
                    # File only
                    # no formatting
                    $thisEntry = $line
                }

                # add to script scope variable if it exists and we're doing an info log
                # this is to cater for the info / host stream not being available in older versions
                # of windows or powershell
                if ($Output -eq "info" -and (Test-Path -Path Variable:Script:log)) {
                    $script:log += $line
                }

                # get log file from params object if executing in script block
                if (Test-Path -Path Variable:Script:Params) {
                    $logFile = $Params.LogFile
                }

                # add to log file
                Add-Content -Path $logFile -Value $thisEntry
            }
        }
    }
    end { }
}

function Get-WUSession {
    # returns a microsoft update session object
    Write-Debug "Get-WUSession: Creating update session object"
    New-Object -ComObject 'Microsoft.Update.Session'
}

function Get-WUUpdateCollection {
    #returns a microsoft update update collection object
    Write-Debug "Get-WUUpdateCollection: Creating update collection object"
    New-Object -ComObject Microsoft.Update.UpdateColl
}

function Get-PendingReboot {
    #Copied from http://ilovepowershell.com/2015/09/10/how-to-check-if-a-server-needs-a-reboot/
    #Adapted from https://gist.github.com/altrive/5329377
    #Based on <http://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542>

    $rebootPending = $false

    if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { $rebootPending = $true }
    if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { $rebootPending = $true }
    if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { $rebootPending = $true }
    try {
        $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
        $status = $util.DetermineIfRebootPending()
        if (($null -ne $status) -and $status.RebootPending) {
            $rebootPending = $true
        }
    }
    catch { }

    if ($rebootPending) { Add-LogEntry "A reboot is required" }

    # return result
    $rebootPending
}

function Invoke-RefreshPuppetFacts {
    # refreshes puppet facts used by os_patching module
    # inputs - $UpdateSession - microsoft update session object
    # outpts - none, saves puppet fact files only
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]$UpdateSession
    )
    # refresh puppet facts

    Add-LogEntry "Refreshing puppet facts"

    $allUpdates = Get-UpdateSearch($UpdateSession)
    # providing we got a result above, get a filtered list of security updates
    if ($null -ne $allUpdates) {
        $securityUpdates = Get-SecurityUpdates($allUpdates)
    }
    else {
        $securityUpdates = $null
    }

    #paths to facts
    $dataDir = 'C:\ProgramData\os_patching'
    $updateFile = Join-Path -Path $dataDir -ChildPath 'package_updates'
    $kbFile = Join-Path -Path $dataDir -ChildPath 'missing_update_kbs'
    $secUpdateFile = Join-Path -Path $dataDir -ChildPath 'security_package_updates'
    $rebootReqdFile = Join-Path -Path $dataDir -ChildPath  'reboot_required'

    # create os_patching data dir if required
    if (-not (Test-Path $dataDir)) { [void](New-Item $dataDir -ItemType Directory) }

    # output list of required updates
    $allUpdates | Select-Object -ExpandProperty Title | Out-File $updateFile -Encoding ascii

    # output list of KBs that need to be applied
    $allUpdates | ForEach-Object { $_.KBArticleIDs | ForEach-Object { "KB$_" } } | Out-File $kbFile -Encoding ascii

    # filter to security updates and output
    $securityUpdates | Select-Object -ExpandProperty Title | Out-File $secUpdateFile -Encoding ascii

    # get pending reboot details
    Get-PendingReboot | Out-File $rebootReqdFile -Encoding ascii

    # upload facts
    Add-LogEntry "Uploading puppet facts"
    $puppetCmd = Join-Path $env:ProgramFiles -ChildPath "Puppet Labs\Puppet\bin\puppet.bat"
    & $puppetCmd facts upload --color=false
}

function Get-UpdateSearch {
    # performs an update search
    # inputs: update session
    # outputs: updates from search result
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$UpdateSession
    )

    # create update searcher
    $updateSearcher = $UpdateSession.CreateUpdateSearcher()

    Add-LogEntry "Performing update search with criteria: $UpdateCriteria"

    try {
        # perform search and select Update property
        $updates = $updateSearcher.Search($UpdateCriteria).Updates
    }
    catch {
        Throw "Unable to search for updates. Is your update source (e.g. WSUS/WindowsUpdate) available? Error: $($_.exception.message)"
    }

    $updateCount = @($updates).count

    Add-LogEntry "Detected $updateCount updates are required in total (including security):"

    $updates | ForEach-Object { Add-LogEntry "  - $($_.title)" }

    # return updates
    $updates
}

function Get-SecurityUpdates {
    # filters update list to security only
    # inputs - update list from an update search
    # outputs - filtered list
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]$Updates
    )
    # filter to security updates
    # add a filterable categories parameter, then filter only to updates that include the security classification
    $secUpdates = $Updates | Add-Member -MemberType ScriptProperty -Name "CategoriesText" -value { $This.Categories | Select-Object -expandproperty Name } -PassThru | Where-Object { $_.CategoriesText -contains "Security Updates" }

    # count them
    if ($secUpdates) {
        $secUpdateCount = @($secUpdates).count

        Add-LogEntry "Detected $secUpdateCount of the required updates are security updates:"

        $secUpdates | ForEach-Object { Add-LogEntry "  - $($_.title)" }

        # return security updates
        $secUpdates
    }
}

# ------------------------------------------------------------------------------------------------------------------------
# Start main script code
# ------------------------------------------------------------------------------------------------------------------------

# trap all unhandled exceptions
trap {
    # using write-error so error goes to stderr which ruby picks up
    Add-LogEntry ("Exception caught: {0} {1} " -f $_.exception.Message, $_.invocationinfo.positionmessage) -Output Error
    # exit
    exit 2
}

# get log file name
$LogFile = Join-Path -Path $LogDir -ChildPath ("os_patching_fact_generation-{0:yyyy_MM_dd-HH_mm_ss}.log" -f (Get-Date))

Add-LogEntry "os_patching_windows_fact_generation: started"

# check and/or create lock file
Save-LockFile

# put all code from here in a try block, so we can use finally to ensure the lock file is removed
# even when the script is aborted with ctrl-c
try {
    # refresh facts
    Invoke-RefreshPuppetFacts -UpdateSession (Get-WUSession)

    # clean log files
    Invoke-CleanLogFile -LogFileFilter "os_patching_fact_generation*.log"
}
finally {
    # this code is always executed, even when an exception is trapped during main script execution

    # remove lock file
    Remove-LockFile

    Add-LogEntry "os_patching_windows_fact_generation: finished"
}
