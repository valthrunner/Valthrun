@echo off
setlocal EnableDelayedExpansion

:: Define the main folder path
set "MAIN_FOLDER=%~dp0"
:: Remove trailing backslash if present
if "%MAIN_FOLDER:~-1%"=="\" set "MAIN_FOLDER=%MAIN_FOLDER:~0,-1%"

:: Fetch the new version of run.bat
curl -s -L -o "%MAIN_FOLDER%\run.bat" "https://raw.githubusercontent.com/valthrunner/valth/Valthrun/run.bat"

:: Execute the updated run.bat
call "%MAIN_FOLDER%\run.bat" %*
