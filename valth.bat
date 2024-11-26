@echo off
setlocal EnableDelayedExpansion

:: Fetch the new version of run.bat
curl -s -L -o "run.bat" "https://raw.githubusercontent.com/valthrunner/Valthrun/main/run.bat"

:: Execute the updated run.bat
call run.bat
