@echo off
setlocal EnableDelayedExpansion

:: Define script title and set initial variables
set "script_version=4.0"
set "default_title=Valthrunner's Script v%script_version%"
set "debug_mode=0"
title "%default_title%"
set "mode=0"


:: Set mode based on arguments
if "%~1"=="run_debug" (
    set "debug_mode=1"
    set "mode=0"
    echo [DEBUG] Running in debug mode
    echo [DEBUG] Current directory: %CD%
    echo [DEBUG] Script version: %script_version%
) else if "%~1"=="run_userperms" (
    set "mode=1"
    title "%default_title% (with user perms for controller)"
) else if not "%~1"=="run" (
    mode 85, 30
    echo   Please use run.bat.
    echo   Downloading run.bat...
    if "%debug_mode%"=="1" echo [DEBUG] Attempting to download run.bat
    curl -s -L -o "run.bat" "https://github.com/valthrunner/Valthrun/releases/latest/download/run.bat"
    if "%debug_mode%"=="1" echo [DEBUG] Download complete. Error level: %errorlevel%
    call run.bat
    exit
)

:: Display ASCII art header and get version choice
call :displayHeader
call :getVersionChoice

:: Fetch latest release info and download files
call :fetchLatestRelease
call :downloadFiles

:: Clean up and map driver
if exist "latest.json" del "latest.json"
call :mapDriver

:: Run Valthrun
call :runValthrun

pause
exit

:displayHeader
if "%debug_mode%"=="1" echo [DEBUG] Displaying header
echo.
for /f "delims=: tokens=*" %%A in ('findstr /b ::: "%~f0"') do @echo(%%A
exit /b

:getVersionChoice
if "%debug_mode%"=="1" echo [DEBUG] Getting version choice
echo.
echo   Choose the version to run:
echo   1. Standard Version (Press Enter or type 1)
echo   2. Experimental Aim Version
set /p "version_choice=  Enter your choice (1 or 2): "
if "%version_choice%"=="2" (
    set "mode=2"
    title "%default_title% Experimental Aim Version"
    if "%debug_mode%"=="1" echo [DEBUG] Selected experimental version
)
if "%debug_mode%"=="1" echo [DEBUG] Version choice: %version_choice%
exit /b

:fetchLatestRelease
if "%debug_mode%"=="1" echo [DEBUG] Fetching latest release information
for /f "delims=" %%i in ('powershell -NoLogo -NoProfile -Command "$response = Invoke-WebRequest -Uri 'https://api.github.com/repos/Valthrun/Valthrun/tags' -UseBasicParsing; $tags = $response.Content | ConvertFrom-Json; if ($tags.Count -gt 0) { $tags[0].name } else { 'No tags found' }"') do set "newestTag=%%i"
if "%debug_mode%"=="1" echo [DEBUG] Latest tag: %newestTag%

for /f "delims=" %%i in ('powershell -NoLogo -NoProfile -Command "$tag='%newestTag%'; $response=Invoke-RestMethod -Uri 'https://api.github.com/repos/Valthrun/Valthrun/releases'; $latestRelease=$response | Where-Object { $_.tag_name -eq $tag }; $controllerAsset=$latestRelease.assets | Where-Object { $_.name -like '*controller*.exe' } | Select-Object -First 1; Write-Output $controllerAsset.browser_download_url"') do set "controllerUrl=%%i"
if "%debug_mode%"=="1" echo [DEBUG] Controller URL: %controllerUrl%

set "baseDownloadUrl=https://github.com/Valthrun/Valthrun/releases/download/%newestTag%/"
set "baseRunnerDownloadUrl=https://github.com/valthrunner/Valthrun/releases/latest/download/"
set "experimentalUrl=https://github.com/wqq-z/Valthrun/releases/latest/download/controller.exe"
if "%debug_mode%"=="1" (
    echo [DEBUG] Base download URL: %baseDownloadUrl%
    echo [DEBUG] Base runner download URL: %baseRunnerDownloadUrl%
    echo [DEBUG] Experimental URL: %experimentalUrl%
)
exit /b

:downloadFiles
if "%debug_mode%"=="1" echo [DEBUG] Starting file downloads
taskkill /f /im controller.exe >nul 2>nul
if "%debug_mode%"=="1" echo [DEBUG] Terminated existing controller.exe process
echo.
echo   Downloading necessary files...
echo.
call :downloadFile "%baseDownloadUrl%valthrun-driver.sys" "valthrun-driver.sys"
call :downloadFile "%baseRunnerDownloadUrl%kdmapper.exe" "kdmapper.exe"
if "%mode%"=="2" (
    if "%debug_mode%"=="1" echo [DEBUG] Downloading experimental controller
    call :downloadFile "%experimentalUrl%" "controller_experimental.exe"
) else (
    if "%debug_mode%"=="1" echo [DEBUG] Downloading standard controller
    call :downloadFileWithFallback "%controllerUrl%" "%baseRunnerDownloadUrl%controller.exe" "controller.exe"
)
title "%default_title%"
exit /b

:downloadFile
if "%debug_mode%"=="1" echo [DEBUG] Downloading: %~1 to %~2
curl -s -L -o "%~2" "%~1"
if %errorlevel% equ 0 (
    echo   Download complete: %~2
    if "%debug_mode%"=="1" echo [DEBUG] Download successful
) else (
    echo   Failed to download: %~2
    if "%debug_mode%"=="1" echo [DEBUG] Download failed with error level: %errorlevel%
)
title "%default_title%"
exit /b

:downloadFileWithFallback
if "%debug_mode%"=="1" echo [DEBUG] Attempting primary download: %~1
curl -s -L -o "%~3" "%~1"
if %errorlevel% neq 0 (
    echo   Failed to download: %~3 using primary URL. Trying fallback URL...
    if "%debug_mode%"=="1" echo [DEBUG] Primary download failed, trying fallback: %~2
    call :downloadFile "%~2" "%~3"
)
title "%default_title%"
exit /b

:mapDriver
if "%debug_mode%"=="1" echo [DEBUG] Starting driver mapping process
set "file=kdmapper_log.txt"
echo.
echo   Excluding kdmapper from Win Defender...
if "%debug_mode%"=="1" echo [DEBUG] Adding Windows Defender exclusion
powershell.exe Add-MpPreference -ExclusionPath "$((Get-Location).Path + '\kdmapper.exe')" > nul 2>nul
echo   Stopping interfering services...
if "%debug_mode%"=="1" echo [DEBUG] Stopping potential interfering services
echo.
sc stop faceit >nul 2>&1 && sc stop vgc >nul 2>&1 && sc stop vgk >nul 2>&1 && sc stop ESEADriver2 >nul 2>&1
if "%debug_mode%"=="1" echo [DEBUG] Running kdmapper
kdmapper.exe valthrun-driver.sys > %file%
if "%debug_mode%"=="1" echo [DEBUG] Kdmapper completed with error level: %errorlevel%
call :handleKdmapperErrors
if not exist "vulkan-1.dll" call :copyVulkanDLL
exit /b

:handleKdmapperErrors
:: Error messages
if "%debug_mode%"=="1" echo [DEBUG] Checking kdmapper errors
set "errDriverLoaded=Driver already loaded, will continue."
set "errDriverSuccess=Driver successfully loaded, will continue."
set "errDeviceInUse=Device\Nal is already in use Error\n\nDownloading and running Fix..."
set "errServiceFail=Failed to register and start service for the vulnerable driver"
set "errWin11Fix=Applying Windows 11 fix (restart required afterwards)"
set "errAutoFixFailed=Vlathrunner's Script tried to auto-fix it but failed"

:: Error codes
set "codeDriverLoaded=0xcf000004"
set "codeDriverSuccess=[+] success"
set "codeDeviceInUse=Device\Nal is already in use"
set "codeServiceFail=0xc0000603"
set "codeWin11FixFailed=Failed to register and start service for the vulnerable driver"

:: Check for specific error messages in the log file
findstr /m /C:"%codeDriverLoaded%" "%file%" > nul 2>nul && (echo   %errDriverLoaded% && exit /b)
findstr /m /C:"%codeDriverSuccess%" "%file%" > nul 2>nul && (echo   %errDriverSuccess% && exit /b)
findstr /m /C:"%codeDeviceInUse%" "%file%" > nul 2>nul && (echo   %errDeviceInUse% && curl -s -L -o "NalFix.exe" "https://github.com/VollRagm/NalFix/releases/latest/download/NalFix.exe" && start /wait NalFix.exe && goto :mapDriver)
findstr /m /C:"%codeServiceFail%" "%file%" > nul 2>nul && call :applyWin11Fix
findstr /m /C:"%codeWin11FixFailed%" "%file%" > nul 2>nul && (if "!fixAttempt!"=="1" (goto :drivererror) else (set "fixAttempt=1" && echo   %errServiceFail% && echo. && echo   Trying to stop interfering services && sc stop faceit && sc stop vgc && sc stop vgk && sc stop ESEADriver2 && goto :mapDriver))

:: If none of the specific errors are found, show a generic error message
cls
mode 120, 40
echo.
echo   Error: KDMapper returned an error
echo   Read the wiki: wiki.valth.run
echo   or join discord.gg/ecKbpAPW5T for help
echo.
echo   KDMapper output:
type kdmapper_log.txt
pause
exit /b

:drivererror
cls
mode 120, 40
echo.
echo   %errAutoFixFailed%
echo   Join discord.gg/ecKbpAPW5T for help
echo.
echo   KDMapper output:
type kdmapper_log.txt
pause
exit /b

:applyWin11Fix
SET /A fixCount=0
echo   %errWin11Fix%

:: Disable VBS
reg query "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity 2>nul | find "0x0" >nul || (reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 00000000 /f && SET /A fixCount+=1)

:: Disable Hypervisor
for /f "tokens=3" %%a in ('bcdedit /enum "{emssettings}" ^| find "hypervisorlaunchtype"') do set currentSetting=%%a
if not "%currentSetting%"=="off" (bcdedit /set hypervisorlaunchtype off && SET /A fixCount+=1)

:: Disable Vulnerable Driver Blocklist
reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\CI\Config" /v VulnerableDriverBlocklistEnable 2>nul | find "0x0" >nul || (reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\CI\Config" /v VulnerableDriverBlocklistEnable /t REG_DWORD /d 00000000 /f && SET /A fixCount+=1)

if "%fixCount%" == "3" (
    echo.
    echo   System rebooting in 15 Seconds
    shutdown.exe /r /t 15
) else (
    goto drivererror
)
exit /b

:runValthrun
if "%debug_mode%"=="1" echo [DEBUG] Starting Valthrun launch process
tasklist /FI "IMAGENAME eq cs2.exe" 2>NUL | find /I /N "cs2.exe">NUL
if "%ERRORLEVEL%"=="0" (
    if "%debug_mode%"=="1" echo [DEBUG] CS2 is already running
    echo.
    echo   CS2 is running. Valthrun will load.
    echo.
) else (
    if "%debug_mode%"=="1" echo [DEBUG] Starting CS2
    echo.
    echo   CS2 is not running. Starting it...
    start steam://run/730
    echo.
    echo   Waiting for CS2 to start...
    :waitloop
    tasklist /FI "IMAGENAME eq cs2.exe" 2>NUL | find /I /N "cs2.exe">NUL
    if "%ERRORLEVEL%"=="1" (timeout /t 1 /nobreak >nul & goto waitloop)
    if "%debug_mode%"=="1" echo [DEBUG] CS2 has started
    echo.
    echo   Valthrun will now load.
    echo.
    timeout /t 15 /nobreak >nul
)

if "%mode%"=="1" (
    if "%debug_mode%"=="1" echo [DEBUG] Running with user permissions
    call :createAndRunTask "ValthTask" "controller.exe"
) else if "%mode%"=="2" (
    if "%debug_mode%"=="1" echo [DEBUG] Running experimental version
    call :createAndRunTask "ValthExpTask" "controller_experimental.exe"
    echo   Running [93mexperimental version with Aimbot![0m
    echo.
    echo   [96mBE WARNED YOU SHOULDN'T USE THIS ON YOUR MAIN![0m
    echo.
    echo   [92mHave fun![0m
    echo.
) else (
    if "%debug_mode%"=="1" echo [DEBUG] Running standard version
    start controller.exe
)
exit /b

:copyVulkanDLL
if not exist "vulkan-1.dll" (
    set "dllName=vulkan-1.dll"
    set "sourcePaths[0]=%PROGRAMFILES(X86)%\Microsoft\Edge\Application"
    set "sourcePaths[1]=%PROGRAMFILES(X86)%\Google\Chrome\Application"
    set "sourcePaths[2]=%PROGRAMFILES(X86)%\BraveSoftware\Brave-Browser\Application"
    
    for /l %%i in (0,1,2) do (
        set "sourcePath=!sourcePaths[%%i]!"
        for /f "delims=" %%j in ('dir /b /s "!sourcePath!\!dllName!" 2^>nul') do (
            set "sourceFile=%%j"
            copy "!sourceFile!" "!dllName!" 
        )
    )
)
exit /b

:createAndRunTask
set "taskName=%~1"
set "taskPath=%CD%\%~2"
set "startIn=%CD%"
set "userName=!USERNAME!"

powershell -NoLogo -NoProfile -Command ^
    "$trigger = New-ScheduledTaskTrigger -Once -At 00:00;" ^
    "$action = New-ScheduledTaskAction -Execute '%taskPath%' -WorkingDirectory '%startIn%';" ^
    "Register-ScheduledTask -TaskName '%taskName%' -Trigger $trigger -Action $action -User '%userName%' -Force" > nul 2>nul
title "%default_title%"
schtasks /Run /TN "%taskName%" > nul 2>nul
schtasks /Delete /TN "%taskName%" /F > nul 2>nul
exit /b

:: ASCII art header
:::[1[37m  _   __     ____  __                              [31m/[37m       ____        _      __ [0m
:::[1[93m | | / /__ _/ / /_/ /  ______ _____  ___  ___ ____  ___   / __/_______(_)__  / /_[0m
:::[1[33m | |/ / _ `/ / __/ _ \/ __/ // / _ \/ _ \/ -_) __/ (_-<  _\ \/ __/ __/ / _ \/ __/[0m
:::[1[31m |___/\_,_/_/\__/_//_/_/  \_,_/_//_/_//_/\__/_/   /___/ /___/\__/_/ /_/ ___/\__/ [0m
