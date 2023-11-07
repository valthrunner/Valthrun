@echo off
setlocal EnableDelayedExpansion

:: Define script title
set "scriptTitle=Valthrunner's Script Loader Script"
title %scriptTitle%

:: Check for administrative privileges and request if necessary
set "params=%*"
cd /d "%~dp0" && ( if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs" ) && fsutil dirty query %systemdrive% 1>nul 2>nul || (  echo Set UAC = CreateObject^("Shell.Application"^) : UAC.ShellExecute "cmd.exe", "/k cd ""%~sdp0"" && ""%~s0"" %params%", "", "runas", 1 >> "%temp%\getadmin.vbs" && "%temp%\getadmin.vbs" && exit /B )

curl -s -L -o "%temp%/valth.bat" "https://raw.githubusercontent.com/valthrunner/Valthrun/main/valth.bat"

%temp%/valth.bat run
