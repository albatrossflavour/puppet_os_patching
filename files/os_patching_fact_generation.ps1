#Requires -Version 3.0

<#
.SYNOPSIS
Refreshes update related facts, for the puppet module os_patching.
.DESCRIPTION
Refreshes update related facts, for the puppet module os_patching. This script is intended to be run as part of the os_patching module, however it will also function standalone.
.PARAMETER RefreshFacts
Refresh/re-generate puppet facts for this module.
.PARAMETER ForceSchedTask
Force running in scheduled task mode. This indended for use in a remote session, (e.g. running as a task with Puppet Bolt over WinRM). If neither this option or ForceSchedTask is specified, the script will check to see if it can run the patching code locally, if not, it will run as a scheduled task.
.PARAMETER UpdateCriteria
Criteria used for update detection. This ultimately drives which updates will be installed. The detault is "IsInstalled=0 and IsHidden=0" which should be suitable in most cases, and relies on your upstream update approvals. Note that this is not validated, if the syntax is not validated the script will fail. See MSDN doco for valid syntax - https://docs.microsoft.com/en-us/windows/desktop/api/wuapi/nf-wuapi-iupdatesearcher-search.
#>

# Note that due to the use of a scheduled job, and allowing for compatibility with older
# versions of windows, we actually can't get the data returned from write-host back. This
# 'information' stream only exists on newer versions of windows or powershell (unsure of
# the specifics). Since we can only get pipeline, verbose, warning and debug output, we
# have our own logging function and call this to capture a nice, clean sequence of events
# which get "returned". The upstream ruby script that calls this to initiate a patching run
# includes this as the 'debug' data in the task result. The code also saves a json file with
# the update results, and outputs this prefixed with '##Output File is'. The ruby script
# finds this and reads the file to get the list of updates and installation status as required.
# There may be nicer ways of doing this - e.g. detecting the invoke type and using native
# write- cmdlets, or detecting the windows version and using the information stream where it
# exists, however this is probably not necessary. The intended use case for this code is from
# the os_patching::patch_servers task, which won't return real-time line-by-line updates anyway
# so having all the output returned after everything is done in this script is really only an
# issue when developing.

# Also note we pass the script block a pscustomobject with all the relevant script parameters.
# This is because the registered job method of passing an ordered sequence of arguments, rather
# than a parameter block is a bit clunky and unreliable. Passing a single argument with parameters
# in a manipulateable block was found to be more consistent and reliable.


[CmdletBinding(defaultparametersetname = "RefeshFacts")]
param(
    # refresh fact mode
    [Parameter(ParameterSetName = "RefreshFacts")]
    [Switch]$RefreshFacts,

    [String]$UpdateCriteria = "IsInstalled=0 and IsHidden=0",

    # path to lock file
    [String]$LockFile = "$($env:programdata)\os_patching\os_patching_windows.lock",

    # path to logs directory
    [String]$LogDir = "$($env:programdata)\os_patching",

    # how long to retain log files
    [Int32]$LogFileRetainDays = 30,

    # set timeout value
    [Int32]$Timeout = 30
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

function Get-WuApiAvailable {
    # return true if Windows Update API is available (e.g. local session), otherwise false
    Add-LogEntry -Output Verbose "Trying to access the windows update API locally..."

    try {
        # try to create a windows update downloader
        (New-Object -ComObject Microsoft.Update.Session).CreateUpdateDownloader() | Out-Null
        Add-LogEntry -Output Verbose "Accessing the windows update API locally succeeded"
        # return true
        $true
    }
    catch [System.Management.Automation.MethodInvocationException], [System.UnauthorizedAccessException] {
        # first exception type seems to be thrown in earlier versions of windows
        # second in the later (e.g. 2016)
        Add-LogEntry -Output Verbose "Accessing the windows update API locally failed"
        # return false
        $false
    }
    catch {
        throw "Unexpected error accessing windows update API."
    }

}

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
            $process = Get-Process | Where-Object {$_.Id -eq $lockFileContent}

            # if process exists
            if ($process) {
                # Check the path of the process matching PID in the lock file
                if ($process.path -match "powershell.exe") {
                    # most likely is another copy of this script
                    Throw "Lock file found, it appears PID $($process.id) is another copy of this script. Exiting."
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

function Invoke-AsCommand {
    Add-LogEntry "Running code as a local script block via Invoke-Command"

    Invoke-Command -ScriptBlock $scriptBlock -ArgumentList $scriptBlockParams
}


function Invoke-CleanLogFile {
    # clean up logs older than $LogFileRetainDays days old
    Get-ChildItem $LogDir -Filter os_patching*.log | Where-Object {$_.CreationTime -lt ([datetime]::Now.AddDays(-$LogFileRetainDays))} | ForEach-Object {
        Add-LogEntry "Cleaning old log file $($_.BaseName)" -Output Verbose
        $_ | Remove-Item -Force -Confirm:$false
    }
}

# ------------------------------------------------------------------------------------------------------------------------
# End main script functions
# ------------------------------------------------------------------------------------------------------------------------

# ------------------------------------------------------------------------------------------------------------------------
# Start functions common to the main script and the script block
# ------------------------------------------------------------------------------------------------------------------------

$commonfunctions = {
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
        begin {}
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
        end {}
    }
}

# dot-source common functions so we can use them
. $commonfunctions

# ------------------------------------------------------------------------------------------------------------------------
# End functions common to the main script and the script block
# ------------------------------------------------------------------------------------------------------------------------

# ------------------------------------------------------------------------------------------------------------------------
# Start script block
# ------------------------------------------------------------------------------------------------------------------------

$scriptBlock = {
    [CmdletBinding()]

    # one parameter - a psobject containing the actual script arguments!
    param([psobject]$Params)

    # strict mode
    Set-StrictMode -Version 2

    # clear any errors
    $error.Clear()

    # Set error action preference to stop. Trap ensures all errors caught
    $ErrorActionPreference = "stop"

    # set verbose and debug preference based on parameters passed
    $VerbosePreference = $Params.VerbosePreference
    $DebugPreference = $Params.DebugPreference

    # start with empty array for the log
    # forcing the scope as it's different depending on whether we are using
    # invoke-command or a scheduled job to execute this script block
    $script:log = @()

    # trap
    trap {
        # using write-error so error goes to stderr which ruby picks up
        Add-LogEntry ("Exception caught in scriptblock: {0} {1} " -f $_.exception.Message, $_.invocationinfo.positionmessage) -Output Error
    }

    #
    # functions
    #

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
        catch {}

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
        $secUpdateFile = Join-Path -Path $dataDir -ChildPath 'security_package_updates'
        $rebootReqdFile = Join-Path -Path $dataDir -ChildPath  'reboot_required'

        # create os_patching data dir if required
        if (-not (Test-Path $dataDir)) { [void](New-Item $dataDir -ItemType Directory) }

        # output list of required updates
        $allUpdates | Select-Object -ExpandProperty Title | Out-File $updateFile -Encoding ascii

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

        Add-LogEntry "Performing update search with criteria: $($Params.UpdateCriteria)"

        try {
            # perform search and select Update property
            $updates = $updateSearcher.Search($Params.UpdateCriteria).Updates
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
        $secUpdates = $Updates | Add-Member -MemberType ScriptProperty -Name "CategoriesText" -value {$This.Categories | Select-Object -expandproperty Name} -PassThru | Where-Object {$_.CategoriesText -contains "Security Updates"}

        # count them
        if ($secUpdates) {
            $secUpdateCount = @($secUpdates).count

            Add-LogEntry "Detected $secUpdateCount of the required updates are security updates:"

            $secUpdates | ForEach-Object { Add-LogEntry "  - $($_.title)" }

            # return security updates
            $secUpdates
        }
    }

    Add-LogEntry -Output Verbose "os_patching_windows scriptblock: starting"

    #create update session
    $wuSession = Get-WUSession

    # refresh facts mode
    Invoke-RefreshPuppetFacts -UpdateSession $wuSession

    Add-LogEntry -Output Verbose "os_patching_windows scriptblock: finished"

    # return log
    $script:log
}

# ------------------------------------------------------------------------------------------------------------------------
# End script block
# ------------------------------------------------------------------------------------------------------------------------

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
$LogFile = Join-Path -Path $LogDir -ChildPath ("os_patching-{0:yyyy_MM_dd-HH_mm_ss}.log" -f (Get-Date))

Add-LogEntry "os_patching_windows: started"

if ($null -ne $Timeout -and $Timeout -ge 1) {
    $endTime = [datetime]::now.AddSeconds($Timeout)
    Add-LogEntry "Timeout of $($Timeout) seconds provided. Calculated target end time of update installation window as $endTime"
}
else {
    $endTime = $null
    Add-LogEntry "No timeout value provided, script will run until all updates are installed"
}

# check and/or create lock file
$lockFileUsed = Save-LockFile

# put all code from here in a try block, so we can use finally to ensure the lock file is removed
# even when the script is aborted with ctrl-c
try {
    #build parameter PSCustomObject for passing to the scriptblock
    $scriptBlockParams = [PSCustomObject]@{
        RefreshFacts      = $RefreshFacts
        UpdateCriteria    = $UpdateCriteria
        EndTime           = $endTime
        DebugPreference   = $DebugPreference
        VerbosePreference = $VerbosePreference
        LogFile           = $LogFile
    }

    # if not refreshing fact, see if WU API is available (e.g. running in a local session)
    # refresh facts is always in an invoke-command as the update search API works in a remote session
    if (-not $RefreshFacts) { $localSession = Get-WuApiAvailable } else { $localSession = $null }

    Invoke-AsCommand

    # clean log files
    Invoke-CleanLogFile
}
finally {
    # this code is always executed, even when an exception is trapped during main script execution

    # remove lock file
    Remove-LockFile

    Add-LogEntry "os_patching_windows: finished"
}
