@echo off
setlocal EnableDelayedExpansion

:: BatchGotAdmin
:-------------------------------------
REM  --> Check for permissions
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

REM --> If error flag set, we do not have admin.
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    set params = %*:"=""
    echo UAC.ShellExecute "cmd.exe", "/c %~s0 %params%", "", "runas", 1 >> "%temp%\getadmin.vbs"

    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    pushd "%CD%"
    CD /D "%~dp0"
:--------------------------------------

:: Fetch the latest release info from GitHub
curl -s https://api.github.com/repos/Valthrun/Valthrun/releases/latest > latest.json

:: Check if the files exist
if not exist "controller.exe" (
    echo controller.exe does not exist. Downloading...
    goto :downloadController
) else if not exist "valthrun-driver.sys" (
    echo valthrun-driver.sys does not exist. Downloading...
    goto :downloadDriver
) else if not exist "kdmapper.exe" (
    echo kdmapper.exe does not exist. Downloading...
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
    echo New version available: v%latestVersion%
    echo Downloading...

    :: Download the new version
    :downloadController
    for /f "delims=" %%u in ('powershell -Command "Get-Content latest.json | ConvertFrom-Json | Select-Object -ExpandProperty assets | Where-Object name -eq 'controller.exe' | Select-Object -ExpandProperty browser_download_url"') do set "downloadUrlcontroller=%%u"
    curl -L -o "controller.exe" "!downloadUrlcontroller!"
    echo Download complete: controller.exe

    :downloadDriver
    for /f "delims=" %%u in ('powershell -Command "Get-Content latest.json | ConvertFrom-Json | Select-Object -ExpandProperty assets | Where-Object name -eq 'valthrun-driver.sys' | Select-Object -ExpandProperty browser_download_url"') do set "downloadUrldriver=%%u"
    curl -L -o "valthrun-driver.sys" "!downloadUrldriver!"

    :downloadKDMapper
    curl -s https://api.github.com/repos/valthrunner/Valthrun/releases/latest > latest.json
    for /f "delims=" %%u in ('powershell -Command "Get-Content latest.json | ConvertFrom-Json | Select-Object -ExpandProperty assets | Where-Object name -eq 'kdmapper.exe' | Select-Object -ExpandProperty browser_download_url"') do set "downloadUrlkdmapper=%%u"
    curl -L -o "kdmapper.exe" "!downloadUrlkdmapper!"

) else (
    echo.
    echo  No new version available.
    echo.
)

:: Cleanup
del latest.json

set "file=kdmapper_log.txt"

:: Run valthrun-driver.sys with kdmapper
::kdmapper.exe valthrun-driver.sys > %file%

set "str1=DriverEntry returned 0xcf000004"
set "str2=DriverEntry returned 0x0"

findstr /m /C:"%str1%" "%file%" > nul
if %errorlevel%==0 (
    echo  Driver already loaded will continue. 
    goto :continue
)

findstr /m /C:"%str2%" "%file%" > nul
if %errorlevel%==0 (
    echo  Driver successfully loaded will continue.
    goto :continue
)

echo  Error: KDMapper return an Error 
echo  Read the wiki: wiki.valth.run
echo  or join discord.gg/valthrun for help
pause
exit /b

:continue

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
        timeout /t 1 /nobreak > NUL
        goto waitloop
    )
    ping -n 15 localhost >NUL
    echo.
    echo  Valthrun will now load.
    echo.
)

:: Create a scheduled task to run the program as the currently logged in user
schtasks /Create /TN "ValthTask" /TR "%CD%/controller.exe" /SC ONCE /ST 00:00 /RU "%USERNAME%" /F > nul 2>&1
:: Run the scheduled task
schtasks /Run /TN "ValthTask" > nul
:: Delete the scheduled task
::schtasks /Delete /TN "ValthTask" /F > nul

:: End of script
pause
