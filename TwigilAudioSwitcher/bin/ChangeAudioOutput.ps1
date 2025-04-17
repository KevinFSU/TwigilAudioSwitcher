param(
    [switch]$RefreshDevices
)

# Prevent any console window from appearing by hiding it.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class ConsoleHider {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
$consoleHandle = [ConsoleHider]::GetConsoleWindow()
if ($consoleHandle -ne [IntPtr]::Zero) {
    # 0 = SW_HIDE. (SW_SHOW would display the window, but we want to hide it.)
    [ConsoleHider]::ShowWindow($consoleHandle, 0)
}

$ErrorActionPreference = "Stop"

# Determine the directory containing this script and the configuration file.
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$configFile = Join-Path $scriptDir "DeviceList.json"

# Function to save the configuration object back to the JSON file.
function Save-Config ($config) {
    $config | ConvertTo-Json -Depth 5 | Out-File $configFile -Encoding UTF8
}

# Function to refresh the list of playback devices from the system.
function Refresh-Devices {
    Write-Host "Refreshing device list from system..." -ForegroundColor Yellow
    Import-Module AudioDeviceCmdlets -ErrorAction Stop
    $allDevices = Get-AudioDevice -List
    $playbackDevices = $allDevices | Where-Object { $_.Type -eq 'Playback' }
    if ($playbackDevices.Count -eq 0) {
        Write-Host "No playback audio devices found." -ForegroundColor Red
        exit 1
    }
    # Ensure each device has a Disabled property.
    foreach ($device in $playbackDevices) {
        if (-not $device.PSObject.Properties.Match("Disabled")) {
            $device | Add-Member -MemberType NoteProperty -Name Disabled -Value $false -Force
        }
    }
    return $playbackDevices
}

# Function to load the configuration from the JSON file.
# If the file does not exist, create one from the current system devices.
function Load-Config {
    if (Test-Path $configFile) {
        $json = Get-Content $configFile -Raw | ConvertFrom-Json
        if (-not $json.Devices) { $json.Devices = @() }
        if (-not $json.CurrentIndex) { $json.CurrentIndex = 0 }
        if (-not $json.HotkeyPattern) { $json.HotkeyPattern = "" }
        return $json
    }
    else {
        Write-Host "Configuration file not found: generating new configuration..." -ForegroundColor Yellow
        $config = [PSCustomObject]@{
            Devices       = Refresh-Devices
            CurrentIndex  = 0
            HotkeyPattern = ""
        }
        Save-Config $config
        return $config
    }
}

# Load configuration.
$config = Load-Config

# If -RefreshDevices is passed, update the Devices list regardless.
if ($RefreshDevices) {
    $config.Devices = Refresh-Devices
    Save-Config $config
    Write-Host "Device list has been refreshed and updated in $configFile" -ForegroundColor Green
    exit 0
}

# If the cached device list is empty, refresh it.
if ($config.Devices.Count -eq 0) {
    $config.Devices = Refresh-Devices
    Save-Config $config
    Write-Host "Device list was empty and has been refreshed and updated." -ForegroundColor Green
}

$devices = $config.Devices
$rawCount = $devices.Count
Write-Host "Total devices in configuration: $rawCount" -ForegroundColor Cyan

# Build an array of indices corresponding to enabled devices.
$enabledIndices = @()
for ($i = 0; $i -lt $devices.Count; $i++) {
    $device = $devices[$i]
    # If the Disabled property exists, use its Boolean value; otherwise assume enabled.
    if ($device.PSObject.Properties["Disabled"]) {
        if (-not $device.Disabled) {
            $enabledIndices += $i
        }
    }
    else {
        $enabledIndices += $i
    }
}

if ($enabledIndices.Count -eq 0) {
    Write-Host "No enabled devices found. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "Enabled device indices: $($enabledIndices -join ', ')" -ForegroundColor Cyan

# Retrieve the current raw index from configuration.
$currentRaw = [int]$config.CurrentIndex
# If the stored index is not enabled, default to the first enabled device.
if ($enabledIndices -notcontains $currentRaw) {
    Write-Host "Current index $currentRaw is not enabled; defaulting to the first enabled device." -ForegroundColor Yellow
    $currentRaw = $enabledIndices[0]
}

# Find the position of this index in the enabled devices array.
$currentPos = $enabledIndices.IndexOf($currentRaw)
# Calculate the next enabled device position cyclically.
$nextPos = ($currentPos + 1) % $enabledIndices.Count
$nextRawIndex = $enabledIndices[$nextPos]
$nextDevice = $devices[$nextRawIndex]

Write-Host "Cycling to next enabled device: $($nextDevice.Name) (Raw index: $nextRawIndex)" -ForegroundColor Green

try {
    # Set the default audio device using the device's Index property from AudioDeviceCmdlets.
    Set-AudioDevice -Index $nextDevice.Index
    Write-Host "Switched default playback device to: $($nextDevice.Name)" -ForegroundColor Green
}
catch {
    Write-Host "Error switching device: $_" -ForegroundColor Red
    exit 1
}

# Update the configuration with the new current index and save it.
$config.CurrentIndex = $nextRawIndex
Save-Config $config
Write-Host "Configuration updated with new CurrentIndex: $nextRawIndex" -ForegroundColor Green
