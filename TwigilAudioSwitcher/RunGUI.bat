@echo off
REM Define the full path to the GUI script located in the bin folder.
set "PSFile=%~dp0bin\TwigilAudioSwitcher.ps1"

REM Check if the GUI script exists.
if not exist "%PSFile%" (
    echo ERROR: The file "%PSFile%" does not exist!
    echo Please verify that the GUI script is located in the 'bin' folder.
    pause
    exit /b
)

REM Launch the PowerShell GUI script in a persistent (no exit) command prompt.
cmd /K powershell -NoProfile -ExecutionPolicy Bypass -File "%PSFile%"
