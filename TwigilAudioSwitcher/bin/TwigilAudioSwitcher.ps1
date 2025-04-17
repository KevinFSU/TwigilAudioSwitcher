# TwigilAudioSwitcherGUI.ps1
# ===============================================
# This lightweight, text-based GUI helps you:
#
# 1. Install the AudioDeviceCmdlets module
# 2. Set the global hotkey (via SetHotkey.ps1)
# 3. Start the persistent hotkey service (StartHotkeyService.ps1)
# 4. Stop the persistent hotkey service
# 5. Manage Audio Devices (Enable/Disable via a "Disabled" flag)
# 6. Update the Audio Device List (force re-querying the system)
# 7. Toggle Auto-Run Hotkey Service at Startup
# 8. Exit GUI
#
# All configuration is stored in a single JSON file, DeviceList.json,
# which holds the list of devices (each with a possible "Disabled" boolean),
# the CurrentIndex, and the HotkeyPattern.
#
# This version launches any subordinate script using hidden window settings 
# and Option 8 now properly exits the GUI.
# ===============================================

function Show-Menu {
    Clear-Host
    Write-Host "Twigil Audio Switcher GUI" -ForegroundColor Cyan
    Write-Host "========================================="
    Write-Host "1. Install AudioDeviceCmdlets module"
    Write-Host "2. Set Hotkey"
    Write-Host "3. Start Hotkey Service"
    Write-Host "4. Stop Hotkey Service"
    Write-Host "5. Manage Audio Devices (Enable/Disable)"
    Write-Host "6. Update Audio Device List"
    Write-Host "7. Toggle Auto-Run Hotkey Service at Startup"
    Write-Host "8. Exit GUI"
    Write-Host ""
}

function Pause {
    Write-Host "Press Enter to continue..."
    [void][System.Console]::ReadLine()
}

# Determine the script directory (assumes all files are co-located).
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
# Path to the combined configuration file.
$configFile = Join-Path $scriptDir "DeviceList.json"

# Paths to other helper scripts.
$setHotkeyPath    = Join-Path $scriptDir "SetHotkey.ps1"
$startServicePath = Join-Path $scriptDir "StartHotkeyService.ps1"
$changeScript     = Join-Path $scriptDir "ChangeAudioOutput.ps1"

while ($true) {
    Show-Menu
    $choice = Read-Host "Enter your choice (1-8)"
    switch ($choice) {
        "1" {
            Write-Host "Checking for AudioDeviceCmdlets module..." -ForegroundColor Yellow
            if (-not (Get-Module -ListAvailable -Name AudioDeviceCmdlets)) {
                Write-Host "Module not installed. Installing..." -ForegroundColor Yellow
                try {
                    Install-Module -Name AudioDeviceCmdlets -Scope CurrentUser -Force
                    Write-Host "AudioDeviceCmdlets module installed successfully." -ForegroundColor Green
                }
                catch {
                    Write-Host "Failed to install AudioDeviceCmdlets." -ForegroundColor Red
                    Write-Host $_.Exception.Message
                }
            }
            else {
                Write-Host "AudioDeviceCmdlets is already installed." -ForegroundColor Green
            }
            Pause
        }
        "2" {
            if (Test-Path $setHotkeyPath) {
                Write-Host "Launching SetHotkey script..." -ForegroundColor Yellow
                # This call is interactive, so we launch it normally.
                & $setHotkeyPath
            }
            else {
                Write-Host "SetHotkey.ps1 not found in $scriptDir" -ForegroundColor Red
            }
            Pause
        }
        "3" {
            if (Test-Path $startServicePath) {
                Write-Host "Starting persistent hotkey service..." -ForegroundColor Yellow
                # Launch StartHotkeyService.ps1 in a hidden process.
                Start-Process -FilePath "powershell.exe" `
                    -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$startServicePath`"" `
                    -WindowStyle Hidden
            }
            else {
                Write-Host "StartHotkeyService.ps1 not found in $scriptDir" -ForegroundColor Red
            }
            Pause
        }
        "4" {
            Write-Host "Attempting to stop the hotkey service..." -ForegroundColor Yellow
            # Look for any processes whose CommandLine contains StartHotkeyService.ps1.
            $processes = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match "StartHotkeyService.ps1" }
            if ($processes) {
                foreach ($p in $processes) {
                    Write-Host "Stopping process ID $($p.ProcessId) running StartHotkeyService.ps1" -ForegroundColor Yellow
                    Stop-Process -Id $p.ProcessId -Force
                }
                Write-Host "Hotkey service stopped." -ForegroundColor Green
            }
            else {
                Write-Host "No running hotkey service found." -ForegroundColor Green
            }
            Pause
        }
        "5" {
            # Manage Audio Devices: allow the user to toggle the "Disabled" flag.
            if (-not (Test-Path $configFile)) {
                Write-Host "Configuration file not found." -ForegroundColor Red
                $updateNow = Read-Host "Would you like to update the device list now? (y/n)"
                if ($updateNow.ToLower() -eq "y") {
                    if (Test-Path $changeScript) {
                        Write-Host "Updating audio devices list..." -ForegroundColor Yellow
                        Start-Process -FilePath "powershell.exe" `
                            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$changeScript`" -RefreshDevices" `
                            -WindowStyle Hidden -Wait
                    }
                    else {
                        Write-Host "ChangeAudioOutput.ps1 not found in $scriptDir" -ForegroundColor Red
                        Pause
                        continue
                    }
                }
                else {
                    Pause
                    continue
                }
            }
            # Configuration file should exist now.
            $config = Get-Content $configFile -Raw | ConvertFrom-Json
            if (-not $config.Devices) {
                Write-Host "No devices found in configuration." -ForegroundColor Red
                Pause
                continue
            }
            # Rebuild the Devices array as mutable PSCustomObjects so that "Disabled" is writable.
            $config.Devices = $config.Devices | ForEach-Object {
                $disabledValue = $false
                if ($_.PSObject.Properties["Disabled"]) {
                    $disabledValue = $_.Disabled
                }
                [PSCustomObject]@{
                    Name     = $_.Name
                    Index    = $_.Index
                    Type     = $_.Type
                    Disabled = $disabledValue
                    # Add any additional properties as needed.
                }
            }
            Write-Host "Audio Devices:" -ForegroundColor Cyan
            $i = 0
            foreach ($device in $config.Devices) {
                $status = if ($device.Disabled) { "Disabled" } else { "Enabled" }
                Write-Host ("{0}: {1} - {2}" -f $i, $device.Name, $status)
                $i++
            }
            $index = Read-Host "Enter the number of a device to toggle its Disabled status (or press Enter to return to menu)"
            if ([string]::IsNullOrWhiteSpace($index)) { continue }
            if ($index -match "^\d+$" -and [int]$index -ge 0 -and [int]$index -lt $config.Devices.Count) {
                $config.Devices[$index].Disabled = -not $config.Devices[$index].Disabled
                $newStatus = if ($config.Devices[$index].Disabled) { "Disabled" } else { "Enabled" }
                Write-Host "Device $index ($($config.Devices[$index].Name)) is now $newStatus" -ForegroundColor Green
                # Save the updated configuration.
                $config | ConvertTo-Json -Depth 5 | Out-File $configFile -Encoding UTF8
            }
            else {
                Write-Host "Invalid index entered." -ForegroundColor Red
            }
            Pause
        }
        "6" {
            # Update Audio Devices: force a refresh of the device list by calling ChangeAudioOutput.ps1 with -RefreshDevices.
            if (Test-Path $changeScript) {
                Write-Host "Updating audio devices list..." -ForegroundColor Yellow
                Start-Process -FilePath "powershell.exe" `
                    -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$changeScript`" -RefreshDevices" `
                    -WindowStyle Hidden -Wait
            }
            else {
                Write-Host "ChangeAudioOutput.ps1 not found in $scriptDir" -ForegroundColor Red
            }
            Pause
        }
        "7" {
            # Toggle Auto-Run for the Hotkey Service: check if a registry key exists, toggle it, and display current status.
            $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
            $keyName = "TwigilAudioSwitcherHotkey"
            try {
                $currentValue = (Get-ItemProperty -Path $regPath -Name $keyName -ErrorAction SilentlyContinue).$keyName
                if ($null -ne $currentValue) {
                    # Auto-run is currently enabled; turn it off.
                    Remove-ItemProperty -Path $regPath -Name $keyName -ErrorAction Stop
                    Write-Host "Auto-run has been disabled. The hotkey service will not run at startup." -ForegroundColor Yellow
                }
                else {
                    # Auto-run is not enabled; so enable it.
                    $value = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$startServicePath`""
                    Set-ItemProperty -Path $regPath -Name $keyName -Value $value -ErrorAction Stop
                    Write-Host "Auto-run has been enabled. The hotkey service will run at startup." -ForegroundColor Green
                }
            }
            catch {
                Write-Host "Failed to toggle auto-run: $_" -ForegroundColor Red
            }
            Pause
        }
        "8" {
            Write-Host "Exiting GUI..." -ForegroundColor Cyan
            exit 0
        }
        default {
            Write-Host "Invalid selection, please choose a number between 1 and 8." -ForegroundColor Red
            Pause
        }
    }
}
