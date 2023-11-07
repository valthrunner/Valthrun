@echo off
setlocal EnableDelayedExpansion

:: Define script title
set "scriptTitle=Valthrunner's Script v2.2"
title %scriptTitle%

echo.
:::[1[37m  _   __     ____  __                              [31m/[37m       ____        _      __ [0m
:::[1[93m | | / /__ _/ / /_/ /  ______ _____  ___  ___ ____  ___   / __/_______(_)__  / /_[0m
:::[1[33m | |/ / _ `/ / __/ _ \/ __/ // / _ \/ _ \/ -_) __/ (_-<  _\ \/ __/ __/ / _ \/ __/[0m
:::[1[31m |___/\_,_/_/\__/_//_/_/  \_,_/_//_/_//_/\__/_/   /___/ /___/\__/_/ /_/ ___/\__/ [0m
:::[1[31m                                                                     /_/         [0m

:: Check if this script was called from another script
if "%~1"=="run" (
    echo.
) else (
    if "%~1"=="run_radar" (
        SET /A RADAR=1
        mode 85, 40
        echo.
        echo  unsing radar version of valthrun!
        echo.
    ) else (
        mode 85, 30
        echo  Please use run.bat.
        echo  Downloading run.bat...
        curl -s -L -o "run.bat" "https://github.com/valthrunner/Valthrun/releases/latest/download/run.bat"
        call run.bat
        exit
    )
)

for /f "delims=: tokens=*" %%A in ('findstr /b ::: "%~f0"') do @echo(%%A

goto download

::this is skipped for now

:: Fetch the latest release info from GitHub
curl -s https://api.github.com/repos/Valthrun/Valthrun/releases/latest > latest.json

:: Check if the files exist
if not exist "controller.exe" (
    echo  controller.exe does not exist. Downloading...
    echo.
    goto :downloadController
) else if not exist "valthrun-driver.sys" (
    echo  valthrun-driver.sys does not exist. Downloading...
    echo.
    goto :downloadDriver
) else if not exist "kdmapper.exe" (
    echo  kdmapper.exe does not exist. Downloading...
    echo.
    goto :downloadKDMapper
)

:: Get the current version of the file
for /f "tokens=2 delims==" %%a in ('wmic datafile where "name='%%cd:\=\\%%\\controller.exe'" get version /value ^| find "Version="') do (
    set "currentVersion=%%a"
)

:: Get the latest version number from GitHub using PowerShell and remove "v" prefix
for /f "delims=" %%i in ('powershell -Command "(Get-Content latest.json | ConvertFrom-Json | Select-Object -ExpandProperty tag_name).Replace('v', '')"') do set "latestVersion=%%i"

:: Extract version numbers for comparison
set "cleanCurrentVersion=!currentVersion:v=!"
set "cleanLatestVersion=!latestVersion!"

:: Compare version numbers
if "!cleanCurrentVersion!" lss "!cleanLatestVersion!" (
    echo  New version available: v%latestVersion%
    :download
    echo.
    echo  Downloading...
    echo.

    :: Download the new version
    :downloadController

    if "%RADAR%" == "1" (
        curl -s -L -o "controller.exe" "https://github.com/valthrunner/Valthrun/releases/latest/download/controller_radar.exe"
        echo  Download complete: controller.exe (radar version!)
    ) else (
    curl -s -L -o "controller.exe" "https://github.com/Valthrun/Valthrun/releases/latest/download/controller.exe"
    :: dont use my controller compile bc offsets changed (but still in here if needed one day)
    :: curl -s -L -o "controller.exe" "https://github.com/valthrunner/Valthrun/releases/latest/download/controller.exe"
    echo  Download complete: controller.exe
    echo.
    )

    :downloadDriver
    curl -s -L -o "valthrun-driver.sys" "https://github.com/Valthrun/Valthrun/releases/latest/download/valthrun-driver.sys"
    echo  Download complete: valthrun-driver.sys
    echo.

    :downloadKDMapper
    curl -s -L -o "kdmapper.exe" "https://github.com/valthrunner/Valthrun/releases/latest/download/kdmapper.exe"
    echo  Download complete: kdmapper.exe
    echo.
    
    goto :cleanup

) else (
    echo  No new version available.
    echo.
)

:cleanup

if exist "latest.json" (
    del latest.json
)

::skip bc not needed

goto delcfgend

:: config changed thats y need to deleted

for /f "tokens=*" %%a in ('set deletedconf 2^>nul') do (
    set "%%a"
)
if not defined deletedconf (
    setx deletedconf 1 /M 

    del config.yaml

    echo.
    echo  config has been deleted because structure changed
    echo.
)

:delcfgend

SET /A XCOUNT=0

:mapdriver

set "file=kdmapper_log.txt"

powershell.exe Add-MpPreference -ExclusionPath ((Get-Location).Path + '\kdmapper.exe') > nul 2>nul

:: Run valthrun-driver.sys with kdmapper
kdmapper.exe valthrun-driver.sys > %file%

set "str1=DriverEntry returned 0xcf000004"
set "str2=DriverEntry returned 0x0"
set "str3=Device\Nal is already in use"
set "str4=0xc0000603"
set "str5=Failed to register and start service for the vulnerable driver"

findstr /m /C:"%str1%" "%file%" > nul 2>nul
if %errorlevel%==0 (
    echo  Driver already loaded will continue. 
    goto :continue
)

findstr /m /C:"%str2%" "%file%" > nul 2>nul
if %errorlevel%==0 (
    echo  Driver successfully loaded will continue.
    goto :continue
)

findstr /m /C:"%str3%" "%file%" > nul 2>nul
if %errorlevel%==0 (
    echo  Device\Nal is already in use Error
    echo.
    echo  Downloading and running Fix...
    curl -s -L -o "NalFix.exe" "https://github.com/VollRagm/NalFix/releases/latest/download/NalFix.exe"
    start /wait NalFix.exe
    goto :mapdriver
)

findstr /m /C:"%str4%" "%file%" > nul 2>nul
if %errorlevel%==0 (
    SET /A XCOUNT1=0
    echo  Failed to register and start service for the vulnerable driver
    echo.
    echo  Applying win11 fix (restart is required afterwards)
    
    reg query "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity 2>nul | find "0x0" >nul
    if %errorlevel% neq 0 (
        reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 00000000 /f
        SET /A XCOUNT1+=1
    )
    for /f "tokens=3" %%a in ('bcdedit /enum "{emssettings}" ^| find "hypervisorlaunchtype"') do set currentsetting=%%a
    if not "%currentsetting%"=="off" (
        bcdedit /set hypervisorlaunchtype off
        SET /A XCOUNT1+=1
    )
    reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\CI\Config" /v VulnerableDriverBlocklistEnable 2>nul | find "0x0" >nul
    if %errorlevel% neq 0 (
        reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\CI\Config" /v VulnerableDriverBlocklistEnable /t REG_DWORD /d 00000000 /f
        SET /A XCOUNT1+=1
    )
    if "%XCOUNT1%" == "3" (
        echo.
        echo  System rebooting in 15 Seconds
        shutdown.exe /r /t 15
    )
    else (
        goto drivererror
    )
)

findstr /m /C:"%str5%" "%file%" 
if %errorlevel%==0 (
    if "%XCOUNT%" == "1" (
      GOTO drivererror
    )
    SET /A XCOUNT+=1
    echo  Failed to register and start service for the vulnerable driver
    echo.
    echo  Trying to stop faceit, vanguard, etc. services
    sc stop faceit
    sc stop vgc
    sc stop vgk
    sc stop ESEADriver2
    goto :mapdriver
)

cls
mode 120, 40
echo.
echo  Error: KDMapper return an Error
echo  Read the wiki: wiki.valth.run
echo  or join discord.gg/valthrun for help
echo.
echo  KDMapper output:
echo.
type kdmapper_log.txt
pause
exit /b

:drivererror

cls
mode 120, 40
echo.
echo  Error: Failed to register and start service for the vulnerable driver
echo  Vlathrunner's Script tried to auto-fix it but failed
echo  join discord.gg/valthrun for help
echo.
echo  KDMapper output:
echo.
type kdmapper_log.txt
pause
exit /b

:continue

if not exist "vulkan-1.dll" (
    set "dllName=vulkan-1.dll"
    
    :: Define an array of potential source paths
    set "sourcePaths[0]=%PROGRAMFILES(X86)%\Microsoft\Edge\Application"
    set "sourcePaths[1]=%PROGRAMFILES(X86)%\Google\Chrome\Application"
    set "sourcePaths[2]=%LOCALAPPDATA%\Discord"
    set "sourcePaths[3]=%PROGRAMFILES(X86)%\BraveSoftware\Brave-Browser\Application"
    
    :: Iterate through the sourcePaths and check for the existence of the DLL file
    for /l %%i in (0,1,3) do (
        set "sourcePath=!sourcePaths[%%i]!"
        for /f "delims=" %%j in ('dir /b /s "!sourcePath!\!dllName!" 2^>nul') do (
            set "sourceFile=%%j"
            copy "!sourceFile!" "!dllName!" 
        )
    )
)

:: Check if cs2.exe is running
tasklist /FI "IMAGENAME eq cs2.exe" 2>NUL | find /I /N "cs2.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo.
    echo  CS2 is running. Valthrun will load.
    echo.
) else (
    echo.
    echo  CS2 is not running. Please wait it will start automatically.
    start steam://run/730
    echo.
    echo  Waiting for CS2 to start...
    :waitloop
    tasklist /FI "IMAGENAME eq cs2.exe" 2>NUL | find /I /N "cs2.exe">NUL
    if "%ERRORLEVEL%"=="1" (
        timeout /t 1 /nobreak >nul
        goto waitloop
    )
    ping -n 20 localhost >nul
    echo.
    echo  Valthrun will now load.
    echo.
)

if "%RADAR%" == "1" (
    echo  Running [93mradar[0m version of controller compiled by valthrunner!
    echo.
    echo  To use the radar locally open [96mhttp://localhost:6969[0m
    echo.
    echo  To share it to you friends take a look here [92mhttps://shorturl.at/fgpyI[0m
    echo.
)

:: Create a scheduled task to run the program as the currently logged in user
schtasks /Create /TN "ValthTask" /TR "%CD%/controller.exe" /SC ONCE /ST 00:00 /RU "%USERNAME%" /F  > nul 2>nul
:: Run the scheduled task
schtasks /Run /TN "ValthTask" > nul 2>nul
:: Delete the scheduled task
schtasks /Delete /TN "ValthTask" /F > nul 2>nul

:: End of script
pause
exit
