@echo off
setlocal EnableDelayedExpansion

:: Initialize timestamp and define log file names
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set timestamp=%%I
set "new_latest_log=latest_script_%timestamp:~0,8%_%timestamp:~8,6%.log"

:: Rename any existing latest_script_<timestamp>.log files to script_<timestamp>.log
for %%F in (latest_script_*.log) do (
    set "old_latest_log=%%F"
    set "renamed_log=!old_latest_log:latest_=!"
    rename "%%F" "!renamed_log!"
)

:: Set the current log file as the latest
set "logfile=%new_latest_log%"

call :logMessage "Script started"
call :logMessage "----------------------------------------"

:: Define script title and set initial variables
set "script_version=5.0"
set "default_title=Valthrunner's Script v%script_version%"
set "debug_mode=0"
title "%default_title%"
set "mode=0"
call :logMessage "Script version: %script_version%"
call :logMessage "Initial mode: %mode%"
call :logMessage "First argument: %~1"

:: Set mode based on the argument
if "%~1"=="run_debug" (
    set "debug_mode=1"
    set "mode=0"
    echo [DEBUG] Running in debug mode
    echo [DEBUG] Current directory: %CD%
    echo [DEBUG] Script version: %script_version%
    call :logMessage "Debug mode enabled"
    call :logMessage "Current directory: %CD%"
) else if "%~1"=="run_userperms" (
    set "mode=1"
    title "%default_title% (with user perms for controller)"
    call :logMessage "Running with user permissions mode"
) else if "%~1"=="run" (
    call :logMessage "Run mode selected"
) else (
    call :logMessage "No valid run parameter, downloading run.bat"
    mode 85, 30
    echo   Please use run.bat.
    echo   Downloading run.bat...
    if "%debug_mode%"=="1" echo [DEBUG] Attempting to download run.bat
    curl -s -L -o "run.bat" "https://github.com/valthrunner/Valthrun/releases/latest/download/run.bat"
    if "%debug_mode%"=="1" echo [DEBUG] Download complete. Error level: %errorlevel%
    call :logMessage "run.bat download completed with error level: %errorlevel%"
    call run.bat
    exit
)

:: Display ASCII art header and get version choice
call :displayHeader
::call :getVersionChoice

:: Fetch latest release info and download files
::call :fetchLatestRelease
::call :downloadFiles

call :downloadAndExtractFiles

:: Clean up and map driver
if exist "latest.json" del "latest.json"
call :mapDriver

:: Run Valthrun
call :runValthrun

call :logMessage "Script execution completed"
call :logMessage "----------------------------------------"
pause
exit

:logMessage
echo [%date% %time%] %~1 >> "%logfile%"
exit /b

:displayHeader
if "%debug_mode%"=="1" echo [DEBUG] Displaying header
call :logMessage "Displaying header"
echo.
for /f "delims=: tokens=*" %%A in ('findstr /b ::: "%~f0"') do @echo(%%A
exit /b

:downloadAndExtractFiles
echo.
echo   Starting download process...
call :logMessage "Starting download process"
if "%debug_mode%"=="1" (
    echo [DEBUG] Starting downloadAndExtractFiles function
    echo [DEBUG] Current directory: %CD%
)

:: Create a temporary directory for extraction
set "temp_dir=%CD%\temp_extract"
call :logMessage "Creating temporary directory: %temp_dir%"
if "%debug_mode%"=="1" echo [DEBUG] Creating temporary directory: %temp_dir%
if not exist "%temp_dir%" mkdir "%temp_dir%"

:: Download controller package
echo   Downloading controller package...
call :logMessage "Downloading controller package"
if "%debug_mode%"=="1" echo [DEBUG] Downloading controller package from valth.run
curl -s -L -H "user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36" -o "%temp_dir%\valthrun_cs2.zip" "https://valth.run/download/cs2"
set "download_error=%errorlevel%"
call :logMessage "Controller package download completed with error level: %download_error%"
if %download_error% neq 0 (
    if "%debug_mode%"=="1" echo [DEBUG] Controller package download failed with error: %download_error%
    echo   Download failed: Controller package
    echo   Please check your internet connection and try again.
    call :logMessage "ERROR: Controller package download failed"
    rmdir /s /q "%temp_dir%" 2>nul
    exit /b 1
)

:: Download driver package
echo   Downloading driver package...
call :logMessage "Downloading driver package"
if "%debug_mode%"=="1" echo [DEBUG] Downloading driver package from valth.run
curl -s -L -H "user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36" -o "%temp_dir%\valthrun_driver_kernel.zip" "https://valth.run/download/driver-kernel"
set "download_error=%errorlevel%"
call :logMessage "Driver package download completed with error level: %download_error%"
if %download_error% neq 0 (
    if "%debug_mode%"=="1" echo [DEBUG] Driver package download failed with error: %download_error%
    echo   Download failed: Driver package
    echo   Please check your internet connection and try again.
    call :logMessage "ERROR: Driver package download failed"
    rmdir /s /q "%temp_dir%" 2>nul
    exit /b 1
)

:: Verify downloads
if "%debug_mode%"=="1" (
    echo [DEBUG] Verifying downloaded files
    dir "%temp_dir%"
)
call :logMessage "Downloads completed successfully"
echo   Downloads completed successfully.

:: Extract controller package
echo   Extracting controller package...
call :logMessage "Extracting controller package"
if "%debug_mode%"=="1" echo [DEBUG] Extracting controller package
powershell -command "& { $ErrorActionPreference = 'Stop'; try { Expand-Archive -Force '%temp_dir%\valthrun_cs2.zip' '%temp_dir%' } catch { Write-Error $_.Exception.Message; exit 1 } }" >"%temp_dir%\extract_cs2.log" 2>&1
set "extract_error=%errorlevel%"
call :logMessage "Controller extraction completed with error level: %extract_error%"
if %extract_error% neq 0 (
    if "%debug_mode%"=="1" (
        echo [DEBUG] Controller extraction failed
        echo [DEBUG] Extract log contents:
        type "%temp_dir%\extract_cs2.log"
    )
    echo   Extraction failed: Controller package
    echo   Try running the script as administrator.
    call :logMessage "ERROR: Controller extraction failed"
    call :logMessage "Extract log contents:"
    type "%temp_dir%\extract_cs2.log" >> "%logfile%"
    rmdir /s /q "%temp_dir%" 2>nul
    exit /b 1
)

:: Extract driver package
echo   Extracting driver package...
call :logMessage "Extracting driver package"
if "%debug_mode%"=="1" echo [DEBUG] Extracting driver package
powershell -command "& { $ErrorActionPreference = 'Stop'; try { Expand-Archive -Force '%temp_dir%\valthrun_driver_kernel.zip' '%temp_dir%' } catch { Write-Error $_.Exception.Message; exit 1 } }" >"%temp_dir%\extract_driver.log" 2>&1
set "extract_error=%errorlevel%"
call :logMessage "Driver extraction completed with error level: %extract_error%"
if %extract_error% neq 0 (
    if "%debug_mode%"=="1" (
        echo [DEBUG] Driver extraction failed
        echo [DEBUG] Extract log contents:
        type "%temp_dir%\extract_driver.log"
    )
    echo   Extraction failed: Driver package
    echo   Try running the script as administrator.
    call :logMessage "ERROR: Driver extraction failed"
    call :logMessage "Extract log contents:"
    type "%temp_dir%\extract_driver.log" >> "%logfile%"
    rmdir /s /q "%temp_dir%" 2>nul
    exit /b 1
)

:: Move and rename files
echo   Processing files...
call :logMessage "Processing extracted files"
if "%debug_mode%"=="1" echo [DEBUG] Processing extracted files
pushd "%temp_dir%"

:: Rename controller
set "controller_found=0"
for %%F in (cs2_overlay_*.exe) do (
    set "controller_found=1"
    call :logMessage "Found controller: %%F"
    if "%debug_mode%"=="1" echo [DEBUG] Found controller: %%F
    move "%%F" "..\controller.exe" >nul 2>&1
    if !errorlevel! neq 0 (
        if "%debug_mode%"=="1" echo [DEBUG] Failed to move controller
        echo   Error: Could not move controller file
        call :logMessage "ERROR: Failed to move controller file"
        popd
        rmdir /s /q "%temp_dir%" 2>nul
        exit /b 1
    )
)
if "!controller_found!"=="0" (
    echo   Error: Controller file not found in package
    call :logMessage "ERROR: Controller file not found in package"
    if "%debug_mode%"=="1" echo [DEBUG] No controller file found
    popd
    rmdir /s /q "%temp_dir%" 2>nul
    exit /b 1
)

:: Remove radar files
for %%F in (*radar*.exe) do (
    call :logMessage "Removing radar file: %%F"
    if "%debug_mode%"=="1" echo [DEBUG] Removing radar file: %%F
    del "%%F" >nul 2>&1
)

:: Rename driver
set "driver_found=0"
for %%F in (kernel_driver_*.sys) do (
    set "driver_found=1"
    call :logMessage "Found driver: %%F"
    if "%debug_mode%"=="1" echo [DEBUG] Found driver: %%F
    move "%%F" "..\valthrun-driver.sys" >nul 2>&1
    if !errorlevel! neq 0 (
        if "%debug_mode%"=="1" echo [DEBUG] Failed to move driver
        echo   Error: Could not move driver file
        call :logMessage "ERROR: Failed to move driver file"
        popd
        rmdir /s /q "%temp_dir%" 2>nul
        exit /b 1
    )
)
if "!driver_found!"=="0" (
    echo   Error: Driver file not found in package
    call :logMessage "ERROR: Driver file not found in package"
    if "%debug_mode%"=="1" echo [DEBUG] No driver file found
    popd
    rmdir /s /q "%temp_dir%" 2>nul
    exit /b 1
)

:: Process interface DLL
set "dll_found=0"
for %%F in (driver_interface_kernel_*.dll) do (
    set "dll_found=1"
    call :logMessage "Found interface DLL: %%F"
    if "%debug_mode%"=="1" echo [DEBUG] Found interface DLL: %%F
    set "interface_dll=%%F"
    move "%%F" "..\%%F" >nul 2>&1
    if !errorlevel! neq 0 (
        if "%debug_mode%"=="1" echo [DEBUG] Failed to move interface DLL
        echo   Error: Could not move interface DLL
        call :logMessage "ERROR: Failed to move interface DLL"
        popd
        rmdir /s /q "%temp_dir%" 2>nul
        exit /b 1
    )
)
if "!dll_found!"=="0" (
    echo   Warning: Interface DLL not found in package
    call :logMessage "WARNING: Interface DLL not found in package"
    if "%debug_mode%"=="1" echo [DEBUG] No interface DLL found
)

popd

:: Download kdmapper
echo   Downloading additional components...
call :logMessage "Downloading kdmapper"
if "%debug_mode%"=="1" echo [DEBUG] Downloading kdmapper
call :downloadFile "https://github.com/valthrunner/Valthrun/releases/latest/download/kdmapper.exe" "kdmapper.exe"

:: Clean up
if "%debug_mode%"=="1" echo [DEBUG] Cleaning up temporary files
call :logMessage "Cleaning up temporary files"
rmdir /s /q "%temp_dir%" 2>nul

if "%debug_mode%"=="1" (
    echo [DEBUG] Final file verification:
    dir controller.exe valthrun-driver.sys kdmapper.exe
)
call :logMessage "File extraction and processing completed"

echo.
echo   [92mAll files downloaded and extracted successfully![0m
exit /b 0

:getVersionChoice
if "%debug_mode%"=="1" echo [DEBUG] Getting version choice
call :logMessage "Getting version choice"
echo.
echo   Choose the version to run:
echo   1. Standard Version (Press Enter or type 1)
echo   2. Experimental Aim Version
set /p "version_choice=  Enter your choice (1 or 2): "
call :logMessage "Version choice selected: %version_choice%"
if "%version_choice%"=="2" (
    set "mode=2"
    title "%default_title% Experimental Aim Version"
    call :logMessage "Experimental version selected"
    if "%debug_mode%"=="1" echo [DEBUG] Selected experimental version
)
if "%debug_mode%"=="1" echo [DEBUG] Version choice: %version_choice%
exit /b

:fetchLatestRelease
if "%debug_mode%"=="1" echo [DEBUG] Fetching latest release information
call :logMessage "Fetching latest release information"
for /f "delims=" %%i in ('powershell -NoLogo -NoProfile -Command "$response = Invoke-WebRequest -Uri 'https://api.github.com/repos/Valthrun/Valthrun/tags' -UseBasicParsing; $tags = $response.Content | ConvertFrom-Json; if ($tags.Count -gt 0) { $tags[0].name } else { 'No tags found' }"') do set "newestTag=%%i"
call :logMessage "Latest tag: %newestTag%"
if "%debug_mode%"=="1" echo [DEBUG] Latest tag: %newestTag%

for /f "delims=" %%i in ('powershell -NoLogo -NoProfile -Command "$tag='%newestTag%'; $response=Invoke-RestMethod -Uri 'https://api.github.com/repos/Valthrun/Valthrun/releases'; $latestRelease=$response | Where-Object { $_.tag_name -eq $tag }; $driverAsset=$latestRelease.assets | Where-Object { $_.name -like 'valthrun-driver*.sys' } | Select-Object -First 1; $controllerAsset=$latestRelease.assets | Where-Object { $_.name -like '*controller*.exe' } | Select-Object -First 1; Write-Output @($driverAsset.browser_download_url, $controllerAsset.browser_download_url)"') do (
    if not defined driverUrl (
        set "driverUrl=%%i"
    ) else (
        set "controllerUrl=%%i"
)
)

call :logMessage "Driver URL: %driverUrl%"
call :logMessage "Controller URL: %controllerUrl%"
if "%debug_mode%"=="1" (
    echo [DEBUG] Driver URL: %driverUrl%
    echo [DEBUG] Controller URL: %controllerUrl%
)

set "baseDownloadUrl=https://github.com/Valthrun/Valthrun/releases/download/%newestTag%/"
set "baseRunnerDownloadUrl=https://github.com/valthrunner/Valthrun/releases/latest/download/"
set "experimentalUrl=https://github.com/wqq-z/Valthrun/releases/latest/download/controller.exe"
call :logMessage "Base download URL: %baseDownloadUrl%"
call :logMessage "Base runner download URL: %baseRunnerDownloadUrl%"
if "%debug_mode%"=="1" (
    echo [DEBUG] Base download URL: %baseDownloadUrl%
    echo [DEBUG] Base runner download URL: %baseRunnerDownloadUrl%
    echo [DEBUG] Experimental URL: %experimentalUrl%
)
exit /b

:downloadFiles
if "%debug_mode%"=="1" echo [DEBUG] Starting file downloads
call :logMessage "Starting file downloads"
taskkill /f /im controller.exe >nul 2>nul
call :logMessage "Terminated existing controller.exe process"
if "%debug_mode%"=="1" echo [DEBUG] Terminated existing controller.exe process
echo.
echo   Downloading necessary files...
echo.
call :downloadFile "%driverUrl%" "valthrun-driver.sys"
call :downloadFile "%baseRunnerDownloadUrl%kdmapper.exe" "kdmapper.exe"
if "%mode%"=="2" (
    call :logMessage "Downloading experimental controller"
    if "%debug_mode%"=="1" echo [DEBUG] Downloading experimental controller
    call :downloadFile "%experimentalUrl%" "controller_experimental.exe"
) else (
    call :logMessage "Downloading standard controller"
    if "%debug_mode%"=="1" echo [DEBUG] Downloading standard controller
    call :downloadFileWithFallback "%controllerUrl%" "%baseRunnerDownloadUrl%controller.exe" "controller.exe"
)
title "%default_title%"
exit /b

:downloadFile
call :logMessage "Downloading: %~1 to %~2"
if "%debug_mode%"=="1" echo [DEBUG] Downloading: %~1 to %~2
curl -s -L -o "%~2" "%~1"
if %errorlevel% equ 0 (
    echo   Download complete: %~2
    call :logMessage "Download successful: %~2"
    if "%debug_mode%"=="1" echo [DEBUG] Download successful
) else (
    echo   Failed to download: %~2
    call :logMessage "ERROR: Failed to download: %~2 (Error level: %errorlevel%)"
    if "%debug_mode%"=="1" echo [DEBUG] Download failed with error level: %errorlevel%
)
title "%default_title%"
exit /b

:downloadFileWithFallback
call :logMessage "Attempting primary download: %~1"
if "%debug_mode%"=="1" echo [DEBUG] Attempting primary download: %~1
curl -s -L -o "%~3" "%~1"
if %errorlevel% neq 0 (
    echo   Failed to download: %~3 using primary URL. Trying fallback URL...
    call :logMessage "Primary download failed, trying fallback: %~2"
    if "%debug_mode%"=="1" echo [DEBUG] Primary download failed, trying fallback: %~2
    call :downloadFile "%~2" "%~3"
)
title "%default_title%"
exit /b

:mapDriver
if "%debug_mode%"=="1" echo [DEBUG] Starting driver mapping process
call :logMessage "Starting driver mapping process"
set "file=kdmapper_log.txt"
echo.
echo   Excluding kdmapper from Win Defender...
call :logMessage "Adding Windows Defender exclusion for kdmapper"
if "%debug_mode%"=="1" echo [DEBUG] Adding Windows Defender exclusion
powershell.exe Add-MpPreference -ExclusionPath "$((Get-Location).Path + '\kdmapper.exe')" > nul 2>nul
echo   Stopping interfering services...
call :logMessage "Stopping potential interfering services"
if "%debug_mode%"=="1" echo [DEBUG] Stopping potential interfering services
echo.
sc stop faceit >nul 2>&1 && sc stop vgc >nul 2>&1 && sc stop vgk >nul 2>&1 && sc stop ESEADriver2 >nul 2>&1
call :logMessage "Running kdmapper"
if "%debug_mode%"=="1" echo [DEBUG] Running kdmapper
kdmapper.exe valthrun-driver.sys > %file%
set "kdmapper_error=%errorlevel%"
call :logMessage "Kdmapper completed with error level: %kdmapper_error%"
if "%debug_mode%"=="1" echo [DEBUG] Kdmapper completed with error level: %kdmapper_error%
call :handleKdmapperErrors
if not exist "vulkan-1.dll" call :copyVulkanDLL
exit /b

:handleKdmapperErrors
:: Error messages
if "%debug_mode%"=="1" echo [DEBUG] Checking kdmapper errors
call :logMessage "Checking kdmapper errors"
set "errDriverLoaded=Driver already loaded, will continue."
set "errDriverSuccess=Driver successfully loaded, will continue."
set "errDeviceInUse=Device\Nal is already in use Error\n\nDownloading and running Fix..."
set "errServiceFail=Failed to register and start service for the vulnerable driver"
set "errWin11Fix=Applying Windows 11 fix (restart required afterwards)"
set "errAutoFixFailed=Vlathrunner's Script tried to auto-fix it but failed"
set "errFunctionCallFailed=Function call to set up the Valthrun Kernel Driver failed. Check DebugView for more details."
set "errInitializationFailed=The Valthrun Kernel Driver failed to initialize. Check DebugView for more details."

:: Error codes
set "codeDriverSuccess=[+] success"
set "codeServiceFail=0xc0000603"
set "codeFunctionCallFailed=0xcf000002"
set "codeFailedToInitialize=0xcf000003"
set "codeDriverLoaded=0xcf000004"

set "codeDeviceInUse=Device\Nal is already in use"

set "codeWin11FixFailed=Failed to register and start service for the vulnerable driver"

:: Check for specific error messages in the log file
findstr /m /C:"%codeDriverLoaded%" "%file%" > nul 2>nul && (
    call :logMessage "Driver already loaded"
    echo   %errDriverLoaded% 
    exit /b
)
findstr /m /C:"%codeDriverSuccess%" "%file%" > nul 2>nul && (
    call :logMessage "Driver successfully loaded"
    echo   %errDriverSuccess% 
    exit /b
)
findstr /m /C:"%codeDeviceInUse%" "%file%" > nul 2>nul && (
    call :logMessage "Device in use error, downloading NalFix"
    echo   %errDeviceInUse% 
    curl -s -L -o "NalFix.exe" "https://github.com/VollRagm/NalFix/releases/latest/download/NalFix.exe" 
    start /wait NalFix.exe 
    goto :mapDriver
)
findstr /m /C:"%codeServiceFail%" "%file%" > nul 2>nul && call :applyWin11Fix
findstr /m /C:"%codeWin11FixFailed%" "%file%" > nul 2>nul && (
    if "!fixAttempt!"=="1" (
        call :logMessage "Fix attempt failed, going to driver error"
        goto :drivererror
    ) else (
        set "fixAttempt=1"
        call :logMessage "Service failure, attempting to stop interfering services"
        echo   %errServiceFail% 
        echo. 
        echo   Trying to stop interfering services 
        sc stop faceit 
        sc stop vgc 
        sc stop vgk 
        sc stop ESEADriver2 
        goto :mapDriver
    )
)

:: Check for specific error messages in the log file
findstr /m /C:"%codeFunctionCallFailed%" "%file%" > nul 2>nul && (
    call :logMessage "Function call setup failed"
    echo   %errFunctionCallFailed%
    exit /b
)
findstr /m /C:"%codeFailedToInitialize%" "%file%" > nul 2>nul && (
    call :logMessage "Initialization failed"
    echo   %errInitializationFailed%
    exit /b
)

:: If none of the specific errors are found, show a generic error message
cls
mode 120, 40
call :logMessage "ERROR: KDMapper returned an unknown error"
echo.
echo   Error: KDMapper returned an error
echo   Read the wiki: wiki.valth.run
echo   or join discord.gg/ecKbpAPW5T for help
echo.
echo   KDMapper output:
type kdmapper_log.txt
call :logMessage "KDMapper output:"
type kdmapper_log.txt >> "%logfile%"
pause
exit /b

:drivererror
cls
mode 120, 40
call :logMessage "ERROR: Auto-fix attempt failed"
echo.
echo   %errAutoFixFailed%
echo   Join discord.gg/ecKbpAPW5T for help
echo.
echo   KDMapper output:
type kdmapper_log.txt
call :logMessage "KDMapper output:"
type kdmapper_log.txt >> "%logfile%"
pause
exit /b

:applyWin11Fix
SET /A fixCount=0
call :logMessage "Applying Windows 11 fix"
echo   %errWin11Fix%

:: Disable VBS
reg query "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity 2>nul | find "0x0" >nul || (
    reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 00000000 /f 
    SET /A fixCount+=1
    call :logMessage "Disabled VBS"
)

:: Disable Hypervisor
for /f "tokens=3" %%a in ('bcdedit /enum "{emssettings}" ^| find "hypervisorlaunchtype"') do set currentSetting=%%a
if not "%currentSetting%"=="off" (
    bcdedit /set hypervisorlaunchtype off 
    SET /A fixCount+=1
    call :logMessage "Disabled Hypervisor"
)

:: Disable Vulnerable Driver Blocklist
reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\CI\Config" /v VulnerableDriverBlocklistEnable 2>nul | find "0x0" >nul || (
    reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\CI\Config" /v VulnerableDriverBlocklistEnable /t REG_DWORD /d 00000000 /f 
    SET /A fixCount+=1
    call :logMessage "Disabled Vulnerable Driver Blocklist"
)

if "%fixCount%" == "3" (
    call :logMessage "All fixes applied, scheduling system reboot"
    echo.
    echo   System rebooting in 15 Seconds
    shutdown.exe /r /t 15
) else (
    call :logMessage "Not all fixes could be applied"
    goto drivererror
)
exit /b

:runValthrun
if "%debug_mode%"=="1" echo [DEBUG] Starting Valthrun launch process
call :logMessage "Starting Valthrun launch process"
tasklist /FI "IMAGENAME eq cs2.exe" 2>NUL | find /I /N "cs2.exe">NUL
if "%ERRORLEVEL%"=="0" (
    if "%debug_mode%"=="1" echo [DEBUG] CS2 is already running
    call :logMessage "CS2 is already running"
    echo.
    echo   CS2 is running. Valthrun will load.
    echo.
) else (
    if "%debug_mode%"=="1" echo [DEBUG] Starting CS2
    call :logMessage "Starting CS2"
    echo.
    echo   CS2 is not running. Starting it...
    start steam://run/730
    echo.
    echo   Waiting for CS2 to start...
    :waitloop
    tasklist /FI "IMAGENAME eq cs2.exe" 2>NUL | find /I /N "cs2.exe">NUL
    if "%ERRORLEVEL%"=="1" (timeout /t 1 /nobreak >nul & goto waitloop)
    call :logMessage "CS2 has started"
    if "%debug_mode%"=="1" echo [DEBUG] CS2 has started
    echo.
    echo   Valthrun will now load.
    echo.
    timeout /t 15 /nobreak >nul
)

if "%mode%"=="1" (
    if "%debug_mode%"=="1" echo [DEBUG] Running with user permissions
    call :logMessage "Running with user permissions"
    call :createAndRunTask "ValthTask" "controller.exe"
) else if "%mode%"=="2" (
    if "%debug_mode%"=="1" echo [DEBUG] Running experimental version
    call :logMessage "Running experimental version"
    call :createAndRunTask "ValthExpTask" "controller_experimental.exe"
    echo   Running [93mexperimental version with Aimbot![0m
    echo.
    echo   [96mBE WARNED YOU SHOULDN'T USE THIS ON YOUR MAIN![0m
    echo.
    echo   [92mHave fun![0m
    echo.
) else (
    if "%debug_mode%"=="1" echo [DEBUG] Running standard version
    call :logMessage "Running standard version"
    start controller.exe
)
exit /b

:copyVulkanDLL
call :logMessage "Checking for vulkan-1.dll"
if not exist "vulkan-1.dll" (
    set "dllName=vulkan-1.dll"
    set "sourcePaths[0]=%PROGRAMFILES(X86)%\Microsoft\Edge\Application"
    set "sourcePaths[1]=%PROGRAMFILES(X86)%\Google\Chrome\Application"
    set "sourcePaths[2]=%PROGRAMFILES(X86)%\BraveSoftware\Brave-Browser\Application"
    
    for /l %%i in (0,1,2) do (
        set "sourcePath=!sourcePaths[%%i]!"
        call :logMessage "Searching for vulkan-1.dll in: !sourcePath!"
        for /f "delims=" %%j in ('dir /b /s "!sourcePath!\!dllName!" 2^>nul') do (
            set "sourceFile=%%j"
            call :logMessage "Found vulkan-1.dll at: !sourceFile!"
            copy "!sourceFile!" "!dllName!" 
            call :logMessage "Copied vulkan-1.dll from: !sourceFile!"
        )
    )
)
exit /b

:createAndRunTask
set "taskName=%~1"
set "taskPath=%CD%\%~2"
set "startIn=%CD%"
set "userName=!USERNAME!"

call :logMessage "Creating scheduled task: %taskName%"
call :logMessage "Task path: %taskPath%"
call :logMessage "Working directory: %startIn%"
call :logMessage "User name: %userName%"

powershell -NoLogo -NoProfile -Command ^
    "$trigger = New-ScheduledTaskTrigger -Once -At 00:00;" ^
    "$action = New-ScheduledTaskAction -Execute '%taskPath%' -WorkingDirectory '%startIn%';" ^
    "Register-ScheduledTask -TaskName '%taskName%' -Trigger $trigger -Action $action -User '%userName%' -Force" > nul 2>nul
title "%default_title%"
schtasks /Run /TN "%taskName%" > nul 2>nul
call :logMessage "Started scheduled task: %taskName%"
schtasks /Delete /TN "%taskName%" /F > nul 2>nul
exit /b

:: ASCII art header
:::[1[37m  _   __     ____  __                              [31m/[37m       ____        _      __ [0m
:::[1[93m | | / /__ _/ / /_/ /  ______ _____  ___  ___ ____  ___   / __/_______(_)__  / /_[0m
:::[1[33m | |/ / _ `/ / __/ _ \/ __/ // / _ \/ _ \/ -_) __/ (_-<  _\ \/ __/ __/ / _ \/ __/[0m
:::[1[31m |___/\_,_/_/\__/_//_/_/  \_,_/_//_/_//_/\__/_/   /___/ /___/\__/_/ /_/ ___/\__/ [0m
:::[1[31m                                                                     /_/         [0m
