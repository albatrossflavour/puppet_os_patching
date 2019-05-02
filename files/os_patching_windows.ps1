#Requires -Version 3.0

#
# Installs windows updates, for the puppet module os_patching.
# Developed by Nathan Giuliani (nathojg@gmail.com) and Tony Green
#
# As the Windows Update Download and Install API commands are not available on a remote session (e.g. executing through WinRM using something like Bolt)
# this script has most of its code in a scriptblock. This is either executed as a scheduled task (for remote/winrm/bolt sessions) or with invoke-command
# for a local run, whitch includes using the PCP/PXP protocol with Puppet Enterprise.
#
# Changelog
#
# v0.9.0 - 2019/04/30
#  - Initial release.
#

<#
.SYNOPSIS
Installs windows updates, for the puppet module os_patching.

.DESCRIPTION
Installs windows updates, for the puppet module os_patching. This script is intended to be run as part of the os_patching module, however it will also function standalone.

The download and install APIs are not available over a remote PowerShell session (e.g. through Puppet Bolt). To overcome this, the script may launch the patching as a scheduled task running as local system.

.PARAMETER ForceLocal
Force running in local mode. This mode is intended for use when running in a local session, (e.g. running as a task with Puppet Enterprise over PCP). If neither this option or ForceSchedTask is specified, the script will check to see if it can run the patching code locally, if not, it will run as a scheduled task.

.PARAMETER ForceSchedTask
Force running in scheduled task mode. This indended for use in a remote session, (e.g. running as a task with Puppet Bolt over WinRM). If neither this option or ForceSchedTask is specified, the script will check to see if it can run the patching code locally, if not, it will run as a scheduled task.

.PARAMETER SecurityOnly
Switch, when set the script will only install updates with a category that includes Security Update.

.PARAMETER UpdateCriteria
Criteria used for update detection. This ultimately drives which updates will be installed. The detault is "IsInstalled=0 and IsHidden=0" which should be suitable in most cases, and relies on your upstream update approvals. Note that this is not validated, if the syntax is not validated the script will fail. See MSDN doco for valid syntax - https://docs.microsoft.com/en-us/windows/desktop/api/wuapi/nf-wuapi-iupdatesearcher-search.

.PARAMETER MaxUpdates
Install only the first X numbmer of updates (at most). Useful ror testing.
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


[CmdletBinding(defaultparametersetname = "InstallUpdates")]
param(
    # force local method
    [Parameter(ParameterSetName = "InstallUpdates-Forcelocal")]
    [Switch]$ForceLocal,

    # force scheduled task method
    [Parameter(ParameterSetName = "InstallUpdates-ForceSchedTask")]
    [Switch]$ForceSchedTask,

    # only install security updates
    [Parameter(ParameterSetName = "InstallUpdates-Forcelocal")]
    [Parameter(ParameterSetName = "InstallUpdates-ForceSchedTask")]
    [Parameter(ParameterSetName = "InstallUpdates")]
    [Switch]$SecurityOnly,

    # update criteria
    [Parameter(ParameterSetName = "InstallUpdates-Forcelocal")]
    [Parameter(ParameterSetName = "InstallUpdates-ForceSchedTask")]
    [String]$UpdateCriteria = "IsInstalled=0 and IsHidden=0",

    [Parameter(ParameterSetName = "InstallUpdates-Forcelocal")]
    [Parameter(ParameterSetName = "InstallUpdates-ForceSchedTask")]
    [Parameter(ParameterSetName = "InstallUpdates")]
    [ValidateScript( { Test-Path -IsValid $_ })]
    [String]$ResultFile,

    # timeout
    [Parameter(ParameterSetName = "InstallUpdates-Forcelocal")]
    [Parameter(ParameterSetName = "InstallUpdates-ForceSchedTask")]
    [Parameter(ParameterSetName = "InstallUpdates")]
    [int32]$Timeout,

    # only install the first x updates
    [Parameter(ParameterSetName = "InstallUpdates-Forcelocal")]
    [Parameter(ParameterSetName = "InstallUpdates-ForceSchedTask")]
    [Parameter(ParameterSetName = "InstallUpdates")]
    [Int32]$MaxUpdates,

    # path to lock file
    [String]$LockFile = "$($env:programdata)\os_patching\os_patching_windows.lock",

    # path to logs directory
    [String]$LogDir = "$($env:programdata)\os_patching",

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

function Invoke-AsCommand {
    Add-LogEntry "Running code as a local script block via Invoke-Command"

    Invoke-Command -ScriptBlock $scriptBlock -ArgumentList $scriptBlockParams
}

function Invoke-AsScheduledTask {
    [CmdletBinding()]
    param (
        [string]$TaskName = "os_patching job",
        [int32]$WaitMS = 500
    )

    Add-LogEntry "Running code as a scheduled task"

    if (Get-ScheduledJob $TaskName -ErrorAction SilentlyContinue) {
        Add-LogEntry -Output Verbose "Removing existing scheduled task first"
        Try {
            Unregister-ScheduledJob $TaskName -Force
        }
        Catch {
            Throw "Unable to remove existing scheduled task, is another copy of this script still running?"
        }
    }

    Add-LogEntry -Output Verbose "Registering scheduled task with a start trigger in 2 seconds time"

    # define scheduled task trigger
    $trigger = @{
        Frequency = "Once" # (or Daily, Weekly, AtStartup, AtLogon)
        At        = $(Get-Date).AddSeconds(10) # in 10 seconds time
    }

    Register-ScheduledJob -name $TaskName -ScriptBlock $scriptBlock -ArgumentList $scriptBlockParams -Trigger $trigger -InitializationScript $commonfunctions | Out-Null

    # Task state reference: https://docs.microsoft.com/en-us/windows/desktop/taskschd/registeredtask-state
    $taskStates = @{
        0 = "Unknown"
        1 = "Disabled"
        2 = "Queued"
        3 = "Ready"
        4 = "Running"
    }
    # Links to task result codes:
    #   https://docs.microsoft.com/en-us/windows/desktop/TaskSchd/task-scheduler-error-and-success-constants
    #   http://www.pgts.com.au/cgi-bin/psql?blog=1803&ndx=b001 (with decimal codes)

    Add-LogEntry -Output Verbose "Waiting for scheduled task to start"

    $taskScheduler = New-Object -ComObject Schedule.Service
    $taskScheduler.Connect("localhost")
    $psTaskFolder = $taskScheduler.GetFolder("\Microsoft\Windows\PowerShell\ScheduledJobs")

    $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

    # wait up to one mintue for the task to start
    # it can take some time especially on older versions of windows
    while ($psTaskFolder.GetTask($TaskName).State -ne 4 -and $stopWatch.ElapsedMilliseconds -lt 60000) {
        Add-LogEntry -Output Verbose "Task Status: $($taskStates[$psTaskFolder.GetTask($TaskName).State]) - Waiting another $($WaitMS)ms for scheduled task to start"
        Start-Sleep -Milliseconds $WaitMS
    }

    Add-LogEntry -Output Verbose "Invoking wait-job to wait for job to finish and get job output."
    Add-LogEntry -Output Verbose "A long pause here means the job is running and we're waiting for results."

    # wait for scheduled task to finish
    # technically we could get into an endless loop here - but the only way around it is to
    # set some arbitary limit (e.g. 3 hours) for the maximum length of a task run and then forcefully
    # terminate the job, which doesn't seem to be a good idea

    $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

    $job = $null
    while ($null -eq $job) {
        if ($stopWatch.ElapsedMilliseconds -gt 60000) {
            throw "Error - scheduled task failed to start within 1 minute"
        }

        try {
            $job = wait-job $TaskName
        }
        catch [System.Management.Automation.PSArgumentException] {
            # wait-job can't see the job yet, this takes some time
            # so wait a bit longer for wait-job to work!
            Add-LogEntry -Output Verbose "  Waiting another $($WaitMS)ms for wait-job to pick up the job."
            Start-Sleep -Milliseconds $WaitMS
        }
    }

    # rumour has it that it can take a while for the job output to be available
    # even after wait-job has finished. wait for 30 seconds here. Thanks for this
    # idea ansible Windows update module!
    $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

    while ($null -eq $job.Output -and $stopWatch.ElapsedMilliseconds -lt 60000) {
        Add-LogEntry -Output Verbose "Waiting another $($WaitMS)ms for job output to populate"
        Start-Sleep -Milliseconds $WaitMS
    }

    Add-LogEntry "Deleting scheduled task"

    $running_tasks = @($taskScheduler.GetRunningTasks(0) | Where-Object { $_.Name -eq $TaskName })
    foreach ($task_to_stop in $running_tasks) {
        Add-LogEntry -Output Verbose "Task still seems to be running, stopping it before unregistering it"
        try {
            $task_to_stop.Stop()
        }
        catch {
            # sometimes the task will stop just before we call stop here
            # catch error and make note of it in the log just in case it's something else
            Add-LogEntry -Output Verbose "Error caught while stopping scheduled task. Continuing anyway: $($_.exception.ToString())"
        }
    }

    Unregister-ScheduledJob $TaskName -Force

    # write any verbose output
    if ($null -ne $job.Verbose) {
        Write-Verbose "Verbose output from scheduled task follows, this will not be in sync with any non-verbose output"
        $job.Verbose | Write-Verbose
    }

    # return job output to pipeline
    $job.Output # pipeline

    # return any error output and exit in a controlled fashion
    if ($job.error) {
        # error output is already in log from scriptblock, no need to add logentry again
        # dump it to the console just in case this is being run interactively
        #Write-Error "Error returned from scriptblock: " -ErrorAction Continue
        $job.Error | Write-Error

        Remove-LockFile
        exit 3
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
        catch { }

        if ($rebootPending) { Add-LogEntry "A reboot is required" }

        # return result
        $rebootPending
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

    function Invoke-UpdateRun {
        # perform an update run
        # inputs - update session
        # outputs - update run results
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory = $true)]$UpdateSession
        )

        # search for (all) updates
        $allUpdates = Get-UpdateSearch($UpdateSession)

        # filter to security updates if switch parameter is set
        if ($Params.SecurityOnly) {
            Add-LogEntry "Only installing updates that include the security update classification"
            $updatesToInstall = Get-SecurityUpdates -Updates $allUpdates
        }
        else {
            $updatesToInstall = $allUpdates
        }

        # filter to maxupdates if required
        if ($Params.MaxUpdates -gt 0) {
            Add-LogEntry "Installing a maximum of $($Params.MaxUpdates) updates"
            $updatesToInstall = $updatesToInstall | Select-Object -First $Params.MaxUpdates
        }

        # get update count
        $updateCount = @($updatesToInstall).count # ensure it's an array so count property exists

        if ($updateCount -gt 0) {
            # we need to install updates

            # download updates if needed. No output from this function
            Invoke-DownloadUpdates -UpdateSession $UpdateSession -UpdatesToDownload $updatesToInstall

            # Install Updates. Pass (return) output to the pipeline
            Invoke-InstallUpdates -UpdateSession $UpdateSession -UpdatesToInstall $updatesToInstall
        }
        else {
            Add-LogEntry "No updates required, no action taken"

            # return null
        }
    }

    function Invoke-DownloadUpdates {
        # download updates if required
        # inputs  - UpdateSession     - update session
        #         - UpdatesToDownload - update collection (of updates to download)
        # outputs - none
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory = $true)]$UpdateSession,
            [Parameter(Mandatory = $true)]$UpdatesToDownload
        )

        # download updates if necessary, i.e. only those where IsDownloaded is false
        $updatesNotDownloaded = $UpdatesToDownload | Where-Object { $_.IsDownloaded -eq $false }

        if ($updatesNotDownloaded) {
            # Create update collection...
            $updateDownloadCollection = Get-WUUpdateCollection

            # ...Add updates to it
            foreach ($update in $updatesNotDownloaded) {
                [void]$updateDownloadCollection.Add($update) # void stops output to console
            }

            Add-LogEntry "Downloading $(@($updateDownloadCollection).Count) updates that are not cached locally"

            # Create update downloader
            $updateDownloader = $updateSession.CreateUpdateDownloader()

            # Set updates to download
            $updateDownloader.Updates = $updateDownloadCollection

            # and download 'em!
            [void]$updateDownloader.Download()
        }
        else {
            Add-LogEntry "All updates are already downloaded"
        }
    }

    function Invoke-InstallUpdates {
        # install updates
        # inputs  - UpdateSession    - update session
        #         - UpdatesToInstall - update collection (of updates to install)
        # outputs - pscustomobject with install results
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory = $true)]$UpdateSession,
            [Parameter(Mandatory = $true)]$UpdatesToInstall
        )

        # get update count
        $updateCount = @($updatesToInstall).count # ensure it's an array so count property exists

        Add-LogEntry "Installing $updateCount updates"

        # create a counter var starting at 1
        $counter = 1

        # create blank array for result output
        $updateInstallResults = @()

        # create update collection object
        $updateInstallCollection = Get-WUUpdateCollection

        # create update installer object
        $updateInstaller = $updateSession.CreateUpdateInstaller()

        foreach ($update in $updatesToInstall) {

            # check if we have time to install updates, e.g. at least 5 minutes left
            #
            # TODO: Be a bit smarter here, perhaps use SCCM's method of estimating 5 minutes
            # per update and 30 minutes per cumulative update?
            #
            if ($null -ne $Params.endtime) {
                if ([datetime]::now -gt $Params.endtime.AddMinutes(-5)) {
                    Add-LogEntry "Skipping remaining updates due to insufficient time"
                    Break
                }
            }

            Add-LogEntry "Installing update $($counter)/$(@($updatesToInstall).Count): $($update.Title)"

            # clear update collection...
            $updateInstallCollection.Clear()

            # ...Add the current update to it
            [void]$updateInstallCollection.Add($update) # void stops output to console

            # Add update collection to the installer
            $updateInstaller.Updates = $updateInstallCollection

            # Install updates and capture result
            $updateInstallResult = $updateInstaller.Install()

            # Convert ResultCode to something readable
            $updateStatus = switch ($updateInstallResult.ResultCode) {
                0 { "NotStarted" }
                1 { "InProgress" }
                2 { "Succeeded" }
                3 { "SucceededWithErrors" }
                4 { "Failed" }
                5 { "Aborted" }
                default { "unknown" }
            }

            # build object with result for this update and add to array
            $updateInstallResults += [pscustomobject]@{
                Title          = $update.Title
                Status         = $updateStatus
                HResult        = $updateInstallResult.HResult
                RebootRequired = $updateInstallResult.RebootRequired
            }

            # increment counter
            $counter++
        }
        # return results
        $updateInstallResults
    }

    Add-LogEntry -Output Verbose "os_patching_windows scriptblock: starting"

    #create update session
    $wuSession = Get-WUSession

    # invoke update run, convert results to CSV and send down the pipeline
    $updateRunResults = Invoke-UpdateRun -UpdateSession $wuSession

    # calculate filename for results file
    $outputFilePath = Join-Path -Path $env:temp -ChildPath ("os_patching-results_{0:yyyy_MM_dd-HH_mm_ss}.json" -f (Get-Date))

    if ($null -ne $updateRunResults) {
        # output as JSON with ASCII encoding which plays nice with puppet etc
        $updateRunResults | ConvertTo-Json | Out-File $outputFilePath -Encoding ascii

        # we want this one in the pipeline no matter what, so that it's returned as output
        # from the scheduled task method
        Add-LogEntry "##Output File is $outputFilePath"
    }
    else {
        # no results, so no output file
        Add-LogEntry "##Output File is not applicable"
    }

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
Save-LockFile

# put all code from here in a try block, so we can use finally to ensure the lock file is removed
# even when the script is aborted with ctrl-c
try {
    #build parameter PSCustomObject for passing to the scriptblock
    $scriptBlockParams = [PSCustomObject]@{
        SecurityOnly      = $SecurityOnly
        UpdateCriteria    = $UpdateCriteria
        MaxUpdates        = $MaxUpdates
        EndTime           = $endTime
        DebugPreference   = $DebugPreference
        VerbosePreference = $VerbosePreference
        LogFile           = $LogFile
    }

    # see if WU API is available (e.g. running in a local session)
    $localSession = Get-WuApiAvailable

    # run either in an invoke-command or a scheduled task based on the result above and provided command line parameters
    if (($localSession -or $ForceLocal) -and -not $ForceSchedTask) {
        if ($ForceLocal) { Add-LogEntry -Output Warning "Forced running locally, this may fail if in a remote session" }
        Invoke-AsCommand
    }
    else {
        if ($ForceSchedTask) { Add-LogEntry -Output Warning "Forced running in a scheduled task, this may not be necessary if running in a local session" }
        Invoke-AsScheduledTask
    }

    # clean log files
    Invoke-CleanLogFile -LogFileFilter "os_patching*.log"
}
finally {
    # this code is always executed, even when an exception is trapped during main script execution

    # remove lock file
    Remove-LockFile

    Add-LogEntry "os_patching_windows: finished"
}
