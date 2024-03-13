@echo off
setlocal EnableDelayedExpansion

:: Define script title and set initial variables
title "Valthrunner's Script v3.0"
set "mode=0"

:: Set mode based on arguments
if "%~1"=="run" (
    echo.
) else if "%~1"=="run_radar" (
    set "mode=1"
    title "Valthrunner's Script v3.0 Radar Version ;)"
    mode 95, 40
    echo.
) else (
    mode 85, 30
    echo   Please use run.bat.
    echo   Downloading run.bat...
    curl -s -L -o "run.bat" "https://github.com/valthrunner/Valthrun/releases/latest/download/run.bat"
    call run.bat
    exit
)

:: Display ASCII art header
echo.
call :displayHeader

:: Fetch the newest release using PowerShell
set "tagsUrl=https://api.github.com/repos/Valthrun/Valthrun/tags"
for /f "delims=" %%i in ('powershell -Command "$response = Invoke-WebRequest -Uri '%tagsUrl%' -UseBasicParsing; $tags = $response.Content | ConvertFrom-Json; if ($tags.Count -gt 0) { $tags[0].name } else { 'No tags found' }"') do set "newestTag=%%i"

:: Fetch the newest controller name using PowerShell
for /f "delims=" %%i in ('powershell -Command "$tag='%newestTag%'; $response=Invoke-RestMethod -Uri 'https://api.github.com/repos/Valthrun/Valthrun/releases'; $latestRelease=$response | Where-Object { $_.tag_name -eq $tag }; $controllerAsset=$latestRelease.assets | Where-Object { $_.name -like '*controller*.exe' } | Select-Object -First 1; Write-Output $controllerAsset.browser_download_url"') do set "controllerUrl=%%i"
echo %controllerUrl%
:: Fetch the newest radar name using PowerShell
for /f "delims=" %%i in ('powershell -Command "$tag='%newestTag%'; $response=Invoke-RestMethod -Uri 'https://api.github.com/repos/Valthrun/Valthrun/releases'; $latestRelease=$response | Where-Object { $_.tag_name -eq $tag }; $radarClientAsset=$latestRelease.assets | Where-Object { $_.name -like '*radar*client*.exe' } | Select-Object -First 1; Write-Output $radarClientAsset.browser_download_url"') do set "radarClientUrl=%%i"
echo %radarClientUrl%
:: Construct the download URLs based on the newest tag
set "baseDownloadUrl=https://github.com/Valthrun/Valthrun/releases/download/%newestTag%/"
set "baseRunnerDownloadUrl=https://github.com/valthrunner/Valthrun/releases/latest/download/"

::Download
echo.
echo   Downloading necessary files...
call :downloadFileWithFallback "%controllerUrl%" "%baseRunnerDownloadUrl%controller.exe" "controller.exe"
call :downloadFile "%baseDownloadUrl%valthrun-driver.sys" "valthrun-driver.sys"
call :downloadFile "%baseRunnerDownloadUrl%kdmapper.exe" "kdmapper.exe"
:: Handle radar version
if "%mode%" == "1" (
    call :downloadFile "%radarClientUrl%" "radar-client.exe"
)

:cleanup
if exist "latest.json" del "latest.json"

SET /A XCOUNT=0

:mapdriver
set "file=kdmapper_log.txt"

:: Exclude kdmapper.exe from Windows Defender
powershell.exe Add-MpPreference -ExclusionPath "$((Get-Location).Path + '\kdmapper.exe')" > nul 2>nul

:: Run valthrun-driver.sys with kdmapper
kdmapper.exe valthrun-driver.sys > %file%

:: Error handling based on kdmapper output
call :handleKdmapperErrors

:continue

:: Copy vulkan-1.dll if not exists
if not exist "vulkan-1.dll" call :copyVulkanDLL

:: Check if cs2.exe is running
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
    if "%ERRORLEVEL%"=="1" (
        timeout /t 1 /nobreak >nul
        goto waitloop
    )
    ping -n 20 localhost >nul
    echo.
    echo   Valthrun will now load.
    echo.
)

:: Run radar or normal version
if "!mode!" == "1" (
    :: Create and run a scheduled task for the controller
    set "taskName=ValthRadarTask"
    set "taskPath=!CD!\radar-client.exe"
    set "startIn=!CD!"
    set "userName=!USERNAME!"
    
    powershell -Command ^
        "$trigger = New-ScheduledTaskTrigger -Once -At 00:00;" ^
        "$action = New-ScheduledTaskAction -Execute '!taskPath!' -WorkingDirectory '!startIn!';" ^
        "Register-ScheduledTask -TaskName '!taskName!' -Trigger $trigger -Action $action -User '!userName!' -Force" > nul 2>nul
    schtasks /Run /TN "!taskName!" > nul 2>nul
    schtasks /Delete /TN "!taskName!" /F > nul 2>nul

    echo   Running [93mradar[0m!
    echo.
    echo   To use the radar open [96https://radar.valth.run/[0m
    echo.
    echo   To share it to you friends take a look at the output and find your temporary share [92mcode[0m
    echo.
)

:: Create and run a scheduled task for the controller
set "taskName=ValthTask"
set "taskPath=%CD%\controller.exe"
set "startIn=%CD%"
set "userName=%USERNAME%"

powershell -Command ^
    "$trigger = New-ScheduledTaskTrigger -Once -At 00:00;" ^
    "$action = New-ScheduledTaskAction -Execute '%taskPath%' -WorkingDirectory '%startIn%';" ^
    "Register-ScheduledTask -TaskName '%taskName%' -Trigger $trigger -Action $action -User '%userName%' -Force" > nul 2>nul
schtasks /Run /TN "%taskName%" > nul 2>nul
schtasks /Delete /TN "%taskName%" /F > nul 2>nul

pause
exit

:displayHeader
:: Display ASCII art header
echo.
:::[1[37m  _   __     ____  __                              [31m/[37m       ____        _      __ [0m
:::[1[93m | | / /__ _/ / /_/ /  ______ _____  ___  ___ ____  ___   / __/_______(_)__  / /_[0m
:::[1[33m | |/ / _ `/ / __/ _ \/ __/ // / _ \/ _ \/ -_) __/ (_-<  _\ \/ __/ __/ / _ \/ __/[0m
:::[1[31m |___/\_,_/_/\__/_//_/_/  \_,_/_//_/_//_/\__/_/   /___/ /___/\__/_/ /_/ ___/\__/ [0m
:::[1[31m                                                                     /_/         [0m

for /f "delims=: tokens=*" %%A in ('findstr /b ::: "%~f0"') do @echo(%%A
exit /b

:downloadFile
curl -s -L -o "%~2" "%~1"

if %errorlevel% equ 0 (
    echo   Download complete: %~2
) else (
    echo   Failed to download: %~2
)
exit /b

:downloadFileWithFallback
curl -s -L -o "%~3" "%~1"
if %errorlevel% equ 0 (
    echo   Download complete: %~3
) else (
    echo   Failed to download: %~3 using primary URL. Trying fallback URL...
    call :downloadFile "%~2" "%~3"
)
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
set "codeDriverSuccess=0x0"
set "codeDeviceInUse=Device\Nal is already in use"
set "codeServiceFail=0xc0000603"
set "codeWin11FixFailed=Failed to register and start service for the vulnerable driver"

:: Check for specific error messages in the log file
findstr /m /C:"%codeDriverLoaded%" "%file%" > nul 2>nul && (echo   %errDriverLoaded% && goto :continue)
findstr /m /C:"%codeDriverSuccess%" "%file%" > nul 2>nul && (echo   %errDriverSuccess% && goto :continue)
findstr /m /C:"%codeDeviceInUse%" "%file%" > nul 2>nul && (echo   %errDeviceInUse% && curl -s -L -o "NalFix.exe" "https://github.com/VollRagm/NalFix/releases/latest/download/NalFix.exe" && start /wait NalFix.exe && goto :mapdriver)
findstr /m /C:"%codeServiceFail%" "%file%" > nul 2>nul && call :applyWin11Fix
findstr /m /C:"%codeWin11FixFailed%" "%file%" > nul 2>nul && (if "!fixAttempt!"=="1" (goto :drivererror) else (set "fixAttempt=1" && echo   %errServiceFail% && echo. && echo   Trying to stop interfering services && sc stop faceit && sc stop vgc && sc stop vgk && sc stop ESEADriver2 && goto :mapdriver))

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

:copyVulkanDLL
if not exist "vulkan-1.dll" (
    set "dllName=vulkan-1.dll"
    
    :: Define an array of potential source paths
    set "sourcePaths[1]=%PROGRAMFILES(X86)%\Google\Chrome\Application"
    set "sourcePaths[0]=%PROGRAMFILES(X86)%\Microsoft\Edge\Application"
    set "sourcePaths[2]=%PROGRAMFILES(X86)%\BraveSoftware\Brave-Browser\Application"
    
    :: Iterate through the sourcePaths and check for the existence of the DLL file
    for /l %%i in (0,1,2) do (
        set "sourcePath=!sourcePaths[%%i]!"
        for /f "delims=" %%j in ('dir /b /s "!sourcePath!\!dllName!" 2^>nul') do (
            set "sourceFile=%%j"
            copy "!sourceFile!" "!dllName!" 
        )
    )
)
exit /b
