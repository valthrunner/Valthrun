@echo off
setlocal EnableDelayedExpansion

:: Define script title and set initial variables
set "script_version=4.0"
set "default_title=Valthrunner's Script v%script_version%"
title "%default_title%"
set "mode=0"

:: Set mode based on arguments
if "%~1"=="run_userperms" (set "mode=1" & title "%default_title% (with user perms for controller)") else if not "%~1"=="run" (
    mode 85, 30
    echo   Please use run.bat.
    echo   Downloading run.bat...
    curl -s -L -o "run.bat" "https://github.com/valthrunner/Valthrun/releases/latest/download/run.bat"
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
echo.
for /f "delims=: tokens=*" %%A in ('findstr /b ::: "%~f0"') do @echo(%%A
exit /b

:getVersionChoice
echo   Choose the version to run:
echo   1. Standard Version (Press Enter or type 1)
echo   2. Experimental Aim Version
set /p "version_choice=Enter your choice (1 or 2): "
if "%version_choice%"=="2" (set "mode=2" & title "%default_title% Experimental Aim Version")
exit /b

:fetchLatestRelease
for /f "delims=" %%i in ('powershell -Command "$response = Invoke-WebRequest -Uri 'https://api.github.com/repos/Valthrun/Valthrun/tags' -UseBasicParsing; $tags = $response.Content | ConvertFrom-Json; if ($tags.Count -gt 0) { $tags[0].name } else { 'No tags found' }"') do set "newestTag=%%i"
for /f "delims=" %%i in ('powershell -Command "$tag='%newestTag%'; $response=Invoke-RestMethod -Uri 'https://api.github.com/repos/Valthrun/Valthrun/releases'; $latestRelease=$response | Where-Object { $_.tag_name -eq $tag }; $controllerAsset=$latestRelease.assets | Where-Object { $_.name -like '*controller*.exe' } | Select-Object -First 1; Write-Output $controllerAsset.browser_download_url"') do set "controllerUrl=%%i"
set "baseDownloadUrl=https://github.com/Valthrun/Valthrun/releases/download/%newestTag%/"
set "baseRunnerDownloadUrl=https://github.com/valthrunner/Valthrun/releases/latest/download/"
set "experimentalUrl=https://github.com/freddyfrank69/Valthrun/releases/latest/download/controller.exe"
exit /b

:downloadFiles
taskkill /f /im controller.exe >nul 2>nul
echo.
echo   Downloading necessary files...
echo.
call :downloadFile "%baseDownloadUrl%valthrun-driver.sys" "valthrun-driver.sys"
call :downloadFile "%baseRunnerDownloadUrl%kdmapper.exe" "kdmapper.exe"
if "%mode%"=="2" (
    call :downloadFile "%experimentalUrl%" "controller_experimental.exe"
) else (
    call :downloadFileWithFallback "%controllerUrl%" "%baseRunnerDownloadUrl%controller.exe" "controller.exe"
)
exit /b

:downloadFile
curl -s -L -o "%~2" "%~1"
if %errorlevel% equ 0 (echo   Download complete: %~2) else (echo   Failed to download: %~2)
exit /b

:downloadFileWithFallback
curl -s -L -o "%~3" "%~1"
if %errorlevel% neq 0 (
    echo   Failed to download: %~3 using primary URL. Trying fallback URL...
    call :downloadFile "%~2" "%~3"
)
exit /b

:mapDriver
set "file=kdmapper_log.txt"
echo.
echo   Excluding kdmapper from Win Defender...
powershell.exe Add-MpPreference -ExclusionPath "$((Get-Location).Path + '\kdmapper.exe')" > nul 2>nul
echo   Stopping interfering services...
echo.
sc stop faceit >nul 2>&1 && sc stop vgc >nul 2>&1 && sc stop vgk >nul 2>&1 && sc stop ESEADriver2 >nul 2>&1
kdmapper.exe valthrun-driver.sys > %file%
call :handleKdmapperErrors
if not exist "vulkan-1.dll" call :copyVulkanDLL
exit /b

:handleKdmapperErrors
:: Error messages
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
tasklist /FI "IMAGENAME eq cs2.exe" 2>NUL | find /I /N "cs2.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo.
    echo   CS2 is running. Valthrun will load.
    echo.
) else (
    echo.
    echo   CS2 is not running. Starting it...
    start steam://run/730
    echo.
    echo   Waiting for CS2 to start...
    :waitloop
    tasklist /FI "IMAGENAME eq cs2.exe" 2>NUL | find /I /N "cs2.exe">NUL
    if "%ERRORLEVEL%"=="1" (timeout /t 1 /nobreak >nul & goto waitloop)
    echo.
    echo   Valthrun will now load.
    echo.
    timeout /t 15 /nobreak >nul
)

if "%mode%"=="1" (
    call :createAndRunTask "ValthTask" "controller.exe"
) else if "%mode%"=="2" (
    call :createAndRunTask "ValthExpTask" "controller_experimental.exe"
    echo   Running [93mexperimental version with Aimbot[0m!
    echo.
    echo   [96BE WARNED YOU SHOULDNT USE THIS ON YOUR MAIN![0m
    echo.
    echo   [92mHave fun![0m
) else (
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

powershell -Command ^
    "$trigger = New-ScheduledTaskTrigger -Once -At 00:00;" ^
    "$action = New-ScheduledTaskAction -Execute '%taskPath%' -WorkingDirectory '%startIn%';" ^
    "Register-ScheduledTask -TaskName '%taskName%' -Trigger $trigger -Action $action -User '%userName%' -Force" > nul 2>nul
schtasks /Run /TN "%taskName%" > nul 2>nul
schtasks /Delete /TN "%taskName%" /F > nul 2>nul
exit /b

::: ASCII art header
:::  _   __     ____  __                              /       ____        _      __ 
::: | | / /__ _/ / /_/ /  ______ _____  ___  ___ ____  ___   / __/_______(_)__  / /_
::: | |/ / _ `/ / __/ _ \/ __/ // / _ \/ _ \/ -_) __/ (_-<  _\ \/ __/ __/ / _ \/ __/
::: |___/\_,_/_/\__/_//_/_/  \_,_/_//_/_//_/\__/_/   /___/ /___/\__/_/ /_/ ___/\__/ 
:::                                                                     /_/