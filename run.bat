@echo off
setlocal EnableDelayedExpansion

:: Check for administrative privileges and request if necessary
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Set UAC = CreateObject^("Shell.Application"^) : UAC.ShellExecute "cmd.exe", "/k cd ""%~sdp0"" && ""%~s0"" %*", "", "runas", 1 > "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B
)

:: Determine the argument to pass
set "ARG=%~1"
if "%ARG%"=="" set "ARG=run"

:: Set the main folder (the folder containing run.bat)
set "MAIN_FOLDER=%~dp0"
:: Remove trailing backslash if present
if "%MAIN_FOLDER:~-1%"=="\" set "MAIN_FOLDER=%MAIN_FOLDER:~0,-1%"

:: Set execution policy and download PowerShell script to temp folder
powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/valthrunner/Valthrun/main/valth.ps1' -OutFile '%temp%\valth.ps1'"

:: Execute PowerShell script with the appropriate argument and main folder path
powershell -ExecutionPolicy Bypass -File "%temp%\valth.ps1" "%ARG%" "%MAIN_FOLDER%"

exit /b
