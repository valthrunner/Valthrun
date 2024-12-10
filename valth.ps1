Clear-Host

# Get the main folder from arguments
$mainFolder = $args[1]

# Define the script directory with proper path handling
$scriptDir = $mainFolder
if (-not [System.IO.Path]::IsPathRooted($scriptDir)) {
    $scriptDir = [System.IO.Path]::GetFullPath($scriptDir)
}

# Define the logs directory with proper path handling
$logDir = Join-Path $scriptDir "logs"
if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}
# Define the versions directory with proper path handling
$versionsDir = Join-Path $scriptDir "versions"
if (!(Test-Path $versionsDir)) {
    New-Item -ItemType Directory -Path $versionsDir | Out-Null
}

# Initialize timestamp and define log file names
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$new_latest_log = "latest_script_$timestamp.log"

# Rename any existing latest_script_<timestamp>.log files to script_<timestamp>.log
Get-ChildItem -Path $logDir -Filter 'latest_script_*.log' | ForEach-Object {
    $old_latest_log = $_.Name
    $renamed_log = $old_latest_log -replace 'latest_', ''
    Rename-Item -Path $_.FullName -NewName $renamed_log -ErrorAction SilentlyContinue
}

# Set the current log file as the latest
$logfile = Join-Path $logDir $new_latest_log

# Initialize WebClient for faster downloads
$client = New-Object System.Net.WebClient
$client.Headers.Add("user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")

# Function to log messages
function LogMessage($message) {
    $timestamp = Get-Date -Format '[yyyy-MM-dd HH:mm:ss]'
    $logEntry = "$timestamp $message"
    $logEntry | Out-File -FilePath $logfile -Append
}

LogMessage "Script started"
LogMessage "----------------------------------------"

# Define script title and set initial variables
$script_version = "6.0"
$default_title = "Valthrunner's Script v$script_version"
$debug_mode = 0
$mode = 0
$skipStartCS = $false

# Check if 'run_test' argument is passed
if ($args -contains "run_test") {
    $skipStartCS = $true
    LogMessage "run_test parameter detected: skipping starting CS"
}

[console]::Title = $default_title
LogMessage "Script version: $script_version"
LogMessage "Initial mode: $mode"
LogMessage "Arguments: $($args -join ' ')"

# Set mode based on the argument
$firstArg = $args[0]

switch ($firstArg) {
    'run_debug' {
        $debug_mode = 1
        $mode = 0
        Write-Host "[DEBUG] Running in debug mode" -ForegroundColor Cyan
        Write-Host "[DEBUG] Current directory: $(Get-Location)" -ForegroundColor Cyan
        Write-Host "[DEBUG] Script version: $script_version" -ForegroundColor Cyan
        LogMessage "Debug mode enabled"
        LogMessage "Current directory: $(Get-Location)"
    }
    'run_userperms' {
        $mode = 1
        [console]::Title = "$default_title (with user perms for controller)"
        LogMessage "Running with user permissions mode"
    }
    'run' {
        LogMessage "Run mode selected"
    }
    default {
        if ($firstArg -ne "run_test") {
            LogMessage "No valid run parameter, downloading run.bat"
            $Host.UI.RawUI.WindowSize = New-Object Management.Automation.Host.Size(85,30)
            Write-Host "  Please use run.bat." -ForegroundColor Yellow
            Write-Host "  Downloading run.bat..." -ForegroundColor Yellow
            if ($debug_mode -eq 1) { Write-Host "[DEBUG] Attempting to download run.bat" -ForegroundColor Cyan }
            try {
                $runBatPath = Join-Path $scriptDir "run.bat"
                $client.DownloadFile("https://github.com/valthrunner/Valthrun/releases/latest/download/run.bat", $runBatPath)
                LogMessage "run.bat download completed"
                if ($debug_mode -eq 1) { Write-Host "[DEBUG] Download complete." -ForegroundColor Cyan }
                # Call run.bat
                Start-Process "cmd.exe" -ArgumentList "/c `"$runBatPath`"" -Verb RunAs
                exit
            } catch {
                Write-Host "  Failed to download run.bat." -ForegroundColor Red
                LogMessage "ERROR: Failed to download run.bat - $_"
                exit 1
            }
        }
    }
}

# Display ASCII art header
function DisplayHeader {
    if ($debug_mode -eq 1) { Write-Host "[DEBUG] Displaying header" -ForegroundColor Cyan }
    LogMessage "Displaying header"

    Write-Host
    Write-Host "  _   __     ____  __                              " -ForegroundColor White -NoNewLine 
    Write-Host "/" -ForegroundColor Red -NoNewLine 
    Write-Host "       ____        _      __" -ForegroundColor White
    Write-Host " | | / /__ _/ / /_/ /  ______ _____  ___  ___ ____  ___   / __/_______(_)__  / /_" -ForegroundColor White
    Write-Host " | |/ / _ `'  / __/ _ \/ __/ // / _ \/ _ \/ -_) __/ (_-<  _\ \/ __/ __/ / _ \/ __/" -ForegroundColor Yellow
    Write-Host " |___/\_,_/_/\__/_//_/_/  \_,_/_//_/_//_/\__/_/   /___/ /___/\__/_/ /_/ ___/\__/" -ForegroundColor Red
    Write-Host "                                                                     /_/         " -ForegroundColor Red
}

DisplayHeader

# Function to get the latest artifact version
function Get-LatestArtifactVersion($artifactSlug) {
    if ($debug_mode -eq 1) { Write-Host "[DEBUG] Getting latest version info for artifact: $artifactSlug" -ForegroundColor Cyan }
    try {
        $artifactInfoUrl = "https://valth.run/api/artifacts/$artifactSlug"
        $artifactInfo = Invoke-RestMethod -Uri $artifactInfoUrl
        $trackId = $artifactInfo.artifact.defaultTrack
        $versionsInfoUrl = "https://valth.run/api/artifacts/$artifactSlug/$trackId"
        $versionsInfo = Invoke-RestMethod -Uri $versionsInfoUrl
        $latestVersion = $versionsInfo.versions | Sort-Object -Property timestamp -Descending | Select-Object -First 1

        return @{
            versionId = $latestVersion.id
            versionHash = $latestVersion.versionHash
            fileName = $latestVersion.fileName
            fileSize = $latestVersion.fileSize
            fileExtension = $latestVersion.fileExtension
            fileType = $latestVersion.fileType
            downloadUrl = "https://valth.run/api/artifacts/$artifactSlug/$trackId/$($latestVersion.id)/download"
        }
    } catch {
        Write-Host "Error getting latest version for artifact ${artifactSlug}: $_" -ForegroundColor Red
        LogMessage "ERROR: Error getting latest version for artifact ${artifactSlug} - $_"
        return $null
    }
}

# Function to download artifacts
function Download-Artifact($artifactSlug, $artifactInfo, $destinationFileName) {
    $downloadUrl = $artifactInfo.downloadUrl
    $versionHash = $artifactInfo.versionHash
    $destinationFile = Join-Path $scriptDir $destinationFileName

    # Read stored version hash
    $versionFile = Join-Path $versionsDir "$artifactSlug.version"
    $storedVersionHash = ""
    if (Test-Path $versionFile) {
        $storedVersionHash = [System.IO.File]::ReadAllText($versionFile)
    }

    # Trim whitespace and convert to lower case for comparison
    $storedVersionHash = $storedVersionHash.Trim().ToLower()
    $versionHash = $versionHash.Trim().ToLower()

    if ($debug_mode -eq 1) {
        Write-Host "[DEBUG] Stored version hash for ${artifactSlug}: '$storedVersionHash'" -ForegroundColor Cyan
        Write-Host "[DEBUG] Latest version hash for ${artifactSlug}: '$versionHash'" -ForegroundColor Cyan
    }

    if ($storedVersionHash -ne $versionHash -or !(Test-Path $destinationFile)) {
        Write-Host "  Downloading $artifactSlug..." -ForegroundColor White
        LogMessage "Downloading $artifactSlug version $versionHash"
        if ($debug_mode -eq 1) {
            Write-Host "[DEBUG] Downloading $artifactSlug from $downloadUrl" -ForegroundColor Cyan
            Write-Host "[DEBUG] Saving as $destinationFile" -ForegroundColor Cyan
        }
        try {
            $client.DownloadFile($downloadUrl, $destinationFile)
            # Save versionHash
            [System.IO.File]::WriteAllText($versionFile, $versionHash)
            Write-Host "  Downloaded $artifactSlug successfully." -ForegroundColor Green
            LogMessage "Downloaded $artifactSlug successfully."
        } catch {
            Write-Host "  Failed to download ${artifactSlug}: $_" -ForegroundColor Red
            LogMessage "ERROR: Failed to download ${artifactSlug} - $_"
            exit 1
        }
    } else {
        Write-Host "  $artifactSlug is up to date." -ForegroundColor Green
        LogMessage "$artifactSlug is up to date."
    }
}

# Download and process artifacts
function DownloadAndExtractFiles {
    Write-Host
    Write-Host "  Starting download process..." -ForegroundColor White
    LogMessage "Starting download process"

    if ($debug_mode -eq 1) {
        Write-Host "[DEBUG] Starting DownloadAndExtractFiles function" -ForegroundColor Cyan
        Write-Host "[DEBUG] Script directory: $scriptDir" -ForegroundColor Cyan
    }

    # List of artifacts to download
    $artifacts = @('driver-interface-kernel','cs2-overlay','kernel-driver')

    # Map artifact slugs to destination filenames
    $artifactFileNames = @{
        'driver-interface-kernel' = 'driver_interface_kernel.dll'
        'cs2-overlay' = 'controller.exe'
        'kernel-driver' = 'valthrun-driver.sys'
    }

    # Hashtable to store artifactInfo
    $artifactInfos = @{}

    foreach ($artifactSlug in $artifacts) {
        $artifactInfo = Get-LatestArtifactVersion $artifactSlug
        if ($null -ne $artifactInfo) {
            $artifactInfos[$artifactSlug] = $artifactInfo
            $destinationFileName = $artifactFileNames[$artifactSlug]
            Download-Artifact $artifactSlug $artifactInfo $destinationFileName
        } else {
            Write-Host "Failed to get latest version info for $artifactSlug" -ForegroundColor Red
            LogMessage "ERROR: Failed to get latest version info for $artifactSlug"
            exit 1
        }
    }

    # Download kdmapper
    Write-Host "  Downloading additional components..." -ForegroundColor White
    LogMessage "Downloading kdmapper"
    if ($debug_mode -eq 1) { Write-Host "[DEBUG] Downloading kdmapper" -ForegroundColor Cyan }
    DownloadFile "https://github.com/valthrunner/Valthrun/releases/latest/download/kdmapper.exe" "kdmapper.exe"

    if ($debug_mode -eq 1) {
        Write-Host "[DEBUG] Final file verification:" -ForegroundColor Cyan
        $files = 'controller.exe', 'valthrun-driver.sys', 'kdmapper.exe'
        Get-ChildItem -Path $scriptDir | Where-Object { $files -contains $_.Name } | ForEach-Object {
            Write-Host $_.Name -ForegroundColor Green
        }
    }
    LogMessage "File download and processing completed"

    Write-Host
    Write-Host "  All files downloaded and processed successfully!" -ForegroundColor Green
}

# Function to download files with proper path handling
function DownloadFile($url, $destination) {
    $destinationPath = Join-Path $scriptDir $destination
    LogMessage "Downloading: $url to $destinationPath"
    
    if ($debug_mode -eq 1) { 
        Write-Host "[DEBUG] Download destination: $destinationPath" -ForegroundColor Cyan 
    }
    
    try {
        $client.DownloadFile($url, $destinationPath)
        Write-Host "  Download complete: $destination" -ForegroundColor Green
        LogMessage "Download successful: $destinationPath"
    } catch {
        Write-Host "  Failed to download: $destination" -ForegroundColor Red
        LogMessage "ERROR: Failed to download: $destinationPath - $_"
    }
}

# Function to ensure proper path handling for kdmapper
function MapDriver {
    if ($debug_mode -eq 1) { Write-Host "[DEBUG] Starting driver mapping process" -ForegroundColor Cyan }
    LogMessage "Starting driver mapping process"

    # Set up kdmapper log file in logs directory with full path
    $kdmapperLogFile = Join-Path $logDir "latest_kdmapper_$timestamp.log"

    Write-Host
    Write-Host "  Excluding kdmapper from Win Defender..." -ForegroundColor White
    LogMessage "Adding Windows Defender exclusion for kdmapper"
    
    $kdmapperPath = Join-Path $scriptDir "kdmapper.exe"
    $driverPath = Join-Path $scriptDir "valthrun-driver.sys"
    
    try {
        Add-MpPreference -ExclusionPath $kdmapperPath -ErrorAction SilentlyContinue
    } catch {
        if ($debug_mode -eq 1) { Write-Host "[DEBUG] Failed to add exclusion for kdmapper.exe" -ForegroundColor Cyan }
    }

    Write-Host "  Stopping interfering services..." -ForegroundColor White
    LogMessage "Stopping potential interfering services"
    
    # Stop services
    'faceit','vgc','vgk','ESEADriver2' | ForEach-Object {
        try {
            Stop-Service -Name $_ -Force -ErrorAction SilentlyContinue
            LogMessage "Stopped service: $_"
        } catch {}
    }

    LogMessage "Running kdmapper with full paths"
    if ($debug_mode -eq 1) { 
        Write-Host "[DEBUG] Running kdmapper from: $kdmapperPath" -ForegroundColor Cyan 
        Write-Host "[DEBUG] Driver path: $driverPath" -ForegroundColor Cyan
    }
    
    try {
        # Use full paths for both kdmapper and driver
        $process = Start-Process -FilePath $kdmapperPath -ArgumentList "`"$driverPath`"" -RedirectStandardOutput $kdmapperLogFile -NoNewWindow -Wait -PassThru
        $kdmapper_error = $process.ExitCode
    } catch {
        $kdmapper_error = 1
        LogMessage "ERROR: Failed to run kdmapper - $_"
    }
    
    LogMessage "Kdmapper completed with error level: $kdmapper_error"
    HandleKdmapperErrors
}

# Handle kdmapper errors
function HandleKdmapperErrors {
    # Implement error checking logic as per the batch script
    if ($debug_mode -eq 1) { Write-Host "[DEBUG] Checking kdmapper errors" -ForegroundColor Cyan }
    LogMessage "Checking kdmapper errors"
    if ($debug_mode -eq 1) {
    Write-Host "[DEBUG] Log file content: $fileContent" -ForegroundColor Cyan
    }

    if (!(Test-Path $kdmapperLogFile)) {
        Write-Host "  Error: kdmapper log file not found." -ForegroundColor Red
        LogMessage "ERROR: kdmapper log file not found."
        Pause
        exit 1
    }

    $fileContent = Get-Content -Path $kdmapperLogFile

    if ($fileContent -match "\[\+\] success") {
        LogMessage "Driver successfully loaded"
        Write-Host "  Driver successfully loaded, will continue." -ForegroundColor Green
    } elseif ($fileContent -match "0xcf000004") {
        LogMessage "Driver already loaded"
        Write-Host "  Driver already loaded, will continue." -ForegroundColor Green
    } elseif ($fileContent -match "Device\\Nal is already in use") {
        LogMessage "Device in use error, downloading NalFix"
        Write-Host "  Device\\Nal is already in use Error" -ForegroundColor Red
        Write-Host
        Write-Host "  Downloading and running Fix..." -ForegroundColor Yellow
        DownloadFile "https://github.com/VollRagm/NalFix/releases/latest/download/NalFix.exe" "NalFix.exe"
        try {
            Start-Process -FilePath (Join-Path $scriptDir "NalFix.exe") -Wait
            LogMessage "NalFix executed"
        } catch {
            LogMessage "ERROR: Failed to execute NalFix - $_"
        }
        MapDriver
    } elseif ($fileContent -match "0xc0000603") {
        ApplyWin11Fix
    } else {
        # Other errors
        LogMessage "ERROR: KDMapper returned an unknown error"
        Write-Host
        Write-Host "  Error: KDMapper returned an error" -ForegroundColor Red
        Write-Host "  Read the wiki: wiki.valth.run" -ForegroundColor Yellow
        Write-Host "  or join discord.gg/ecKbpAPW5T for help" -ForegroundColor Yellow
        Write-Host
        Write-Host "  KDMapper output:" -ForegroundColor White
        Write-Host $fileContent -ForegroundColor Red
        LogMessage "KDMapper output:"
        $fileContent | Out-File -FilePath $logfile -Append
        Pause
        exit 1
    }
}

# Apply Windows 11 fix
function ApplyWin11Fix {
    $fixCount = 0
    LogMessage "Applying Windows 11 fix"
    Write-Host "  Applying Windows 11 fix (restart required afterwards)" -ForegroundColor White

    # Disable VBS
    $vbsKey = 'HKLM:\System\CurrentControlSet\Control\DeviceGuard'
    try {
        $vbsValue = Get-ItemProperty -Path $vbsKey -Name EnableVirtualizationBasedSecurity -ErrorAction SilentlyContinue
        if ($vbsValue.EnableVirtualizationBasedSecurity -ne 0) {
            Set-ItemProperty -Path $vbsKey -Name EnableVirtualizationBasedSecurity -Value 0
            $fixCount++
            LogMessage "Disabled VBS"
        }
    } catch {}

    # Disable Hypervisor
    try {
        $currentSetting = (bcdedit /enum '{current}' | Select-String 'hypervisorlaunchtype').ToString()
        if ($currentSetting -notmatch 'off') {
            bcdedit /set hypervisorlaunchtype off | Out-Null
            $fixCount++
            LogMessage "Disabled Hypervisor"
        }
    } catch {}

    # Disable Vulnerable Driver Blocklist
    $ciKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Config'
    try {
        $ciValue = Get-ItemProperty -Path $ciKey -Name VulnerableDriverBlocklistEnable -ErrorAction SilentlyContinue
        if ($ciValue.VulnerableDriverBlocklistEnable -ne 0) {
            Set-ItemProperty -Path $ciKey -Name VulnerableDriverBlocklistEnable -Value 0
            $fixCount++
            LogMessage "Disabled Vulnerable Driver Blocklist"
        }
    } catch {}

    if ($fixCount -eq 3) {
        LogMessage "All fixes applied, scheduling system reboot"
        Write-Host
        Write-Host "  System rebooting in 15 Seconds" -ForegroundColor Yellow
        shutdown.exe /r /t 15
    } else {
        LogMessage "Not all fixes could be applied"
        HandleKdmapperErrors
    }
}

# Copy Vulkan DLL if necessary
function CopyVulkanDLL {
    LogMessage "Checking for vulkan-1.dll"
    if (!(Test-Path (Join-Path $scriptDir "vulkan-1.dll"))) {
        $dllName = 'vulkan-1.dll'
        $baseDir = ${env:ProgramFiles(x86)}
        $sourcePaths = @(
            "$baseDir\Microsoft\Edge\Application",
            "$baseDir\Google\Chrome\Application",
            "$baseDir\BraveSoftware\Brave-Browser\Application"
        )

        foreach ($sourcePath in $sourcePaths) {
            LogMessage "Searching for vulkan-1.dll in: $sourcePath"
            $foundFiles = Get-ChildItem -Path $sourcePath -Filter $dllName -Recurse -ErrorAction SilentlyContinue
            foreach ($file in $foundFiles) {
                LogMessage "Found vulkan-1.dll at: $($file.FullName)"
                try {
                    Copy-Item -Path $file.FullName -Destination (Join-Path $scriptDir $dllName) -Force
                    LogMessage "Copied vulkan-1.dll from: $($file.FullName)"
                    break
                } catch {
                    LogMessage "ERROR: Failed to copy vulkan-1.dll from: $($file.FullName) - $_"
                }
            }
        }
    }
}

# Create and run scheduled task
function CreateAndRunTask($taskName, $taskPath) {
    $startIn = $scriptDir
    $userName = $env:USERNAME

    LogMessage "Creating scheduled task: $taskName"
    LogMessage "Task path: $taskPath"
    LogMessage "Working directory: $startIn"
    LogMessage "User name: $userName"

    try {
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddMinutes(1)
        $action = New-ScheduledTaskAction -Execute (Join-Path $startIn $taskPath) -WorkingDirectory $startIn
        Register-ScheduledTask -TaskName $taskName -Trigger $trigger -Action $action -User "$env:COMPUTERNAME\$userName" -RunLevel Highest -Force -ErrorAction Stop | Out-Null
        [console]::Title = $default_title
        Start-ScheduledTask -TaskName $taskName
        LogMessage "Started scheduled task: $taskName"
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    } catch {
        LogMessage "ERROR: Failed to create or run scheduled task: $taskName - $_"
        Write-Host "  ERROR: Could not create or run scheduled task: $taskName" -ForegroundColor Red
    }
}

# Run Valthrun
function RunValthrun {
    if ($debug_mode -eq 1) { Write-Host "[DEBUG] Starting Valthrun launch process" -ForegroundColor Cyan }
    LogMessage "Starting Valthrun launch process"

    $cs2_running = Get-Process -Name 'cs2' -ErrorAction SilentlyContinue
    if ($cs2_running) {
        if ($debug_mode -eq 1) { Write-Host "[DEBUG] CS2 is already running" -ForegroundColor Cyan }
        LogMessage "CS2 is already running"
        Write-Host
        Write-Host "  CS2 is running. Valthrun will load." -ForegroundColor Green
        Write-Host
    } else {
        if ($debug_mode -eq 1) { Write-Host "[DEBUG] Starting CS2" -ForegroundColor Cyan }
        LogMessage "Starting CS2"
        Write-Host
        Write-Host "  CS2 is not running. Starting it..." -ForegroundColor Yellow
        Start-Process 'steam://run/730'
        Write-Host
        Write-Host "  Waiting for CS2 to start..." -ForegroundColor White
        do {
            Start-Sleep -Seconds 1
            $cs2_running = Get-Process -Name 'cs2' -ErrorAction SilentlyContinue
        } until ($cs2_running)
        LogMessage "CS2 has started"
        if ($debug_mode -eq 1) { Write-Host "[DEBUG] CS2 has started" -ForegroundColor Cyan }
        Write-Host
        Write-Host "  Valthrun will now load." -ForegroundColor Green
        Write-Host
        Start-Sleep -Seconds 15
    }

    if ($skipStartCS -eq $false) {
        if ($mode -eq 1) {
            if ($debug_mode -eq 1) { Write-Host "[DEBUG] Running with user permissions" -ForegroundColor Cyan }
            LogMessage "Running with user permissions"
            CreateAndRunTask "ValthTask" "controller.exe"
        } elseif ($mode -eq 2) {
            if ($debug_mode -eq 1) { Write-Host "[DEBUG] Running experimental version" -ForegroundColor Cyan }
            LogMessage "Running experimental version"
            CreateAndRunTask "ValthExpTask" "controller_experimental.exe"
            Write-Host "  Running experimental version with Aimbot!" -ForegroundColor Green
            Write-Host
            Write-Host "  BE WARNED YOU SHOULDN'T USE THIS ON YOUR MAIN!" -ForegroundColor Red
            Write-Host
            Write-Host "  Have fun!" -ForegroundColor Green
            Write-Host
        } else {
            if ($debug_mode -eq 1) { Write-Host "[DEBUG] Running standard version" -ForegroundColor Cyan }
            LogMessage "Running standard version"
            Start-Process 'controller.exe'
        }
    } else {
        Write-Host "  Run_test mode: CS will not be started automatically." -ForegroundColor Yellow
        LogMessage "Run_test mode: Skipping starting CS"
    }
}

# Main Execution
DownloadAndExtractFiles
MapDriver
RunValthrun

# Dispose of WebClient
$client.Dispose()

LogMessage "Script execution completed"
LogMessage "----------------------------------------"
Pause
Exit
