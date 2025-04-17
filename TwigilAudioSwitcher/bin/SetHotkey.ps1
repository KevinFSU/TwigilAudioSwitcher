# SetHotkey.ps1
# ===============================================
# This script allows the user to set a desired global hotkey pattern 
# for switching audio devices. It updates the combined configuration file 
# (DeviceList.json) with the new hotkey pattern.
#
# All configuration (Devices, CurrentIndex, and HotkeyPattern) is stored 
# in DeviceList.json (located in the same folder as these scripts).
# ===============================================

$ErrorActionPreference = "Stop"

# Determine the directory for the configuration file.
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$configFile = Join-Path $scriptDir "DeviceList.json"

function Load-Config {
    if (Test-Path $configFile) {
        $json = Get-Content $configFile -Raw | ConvertFrom-Json
        if (-not $json.Devices) { $json.Devices = @() }
        if (-not $json.CurrentIndex) { $json.CurrentIndex = 0 }
        if (-not $json.HotkeyPattern) { $json.HotkeyPattern = "" }
        return $json
    } else {
        # Create a default config object if none exists.
        $config = [PSCustomObject]@{
            Devices       = @()
            CurrentIndex  = 0
            HotkeyPattern = ""
        }
        $config | ConvertTo-Json -Depth 5 | Out-File $configFile -Encoding UTF8
        return $config
    }
}

function Save-Config ($config) {
    $config | ConvertTo-Json -Depth 5 | Out-File $configFile -Encoding UTF8
}

# Function to parse a hotkey pattern string.
function Parse-Hotkey {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )
    $modValue = 0
    $tokens = $Pattern -split '\+'
    for ($i = 0; $i -lt ($tokens.Length - 1); $i++) {
        $token = $tokens[$i].Trim().ToLower()
        switch ($token) {
            "ctrl" { $modValue += 0x0002 }
            "control" { $modValue += 0x0002 }
            "alt" { $modValue += 0x0001 }
            "shift" { $modValue += 0x0004 }
            "win" { $modValue += 0x0008 }
            default { }
        }
    }
    $keyToken = $tokens[-1].Trim().ToUpper()
    if ($keyToken.Length -eq 1) {
        $vk = [uint32][char]$keyToken
    }
    else {
        try {
            $keyEnum = [System.Windows.Forms.Keys]::Parse([type]"System.Windows.Forms.Keys", $keyToken)
            $vk = [uint32]$keyEnum
        }
        catch {
            Write-Host "Could not parse key token: $keyToken" -ForegroundColor Red
            return $null
        }
    }
    return @{ Modifiers = [uint32]$modValue; VKey = [uint32]$vk }
}

Write-Host "=== SetHotkey Configuration ===" -ForegroundColor Cyan

# Load the configuration.
$config = Load-Config

# If a hotkey pattern is already set, show it and ask if the user wants to change it.
if (-not [string]::IsNullOrWhiteSpace($config.HotkeyPattern)) {
    Write-Host "A hotkey is already set to: $($config.HotkeyPattern)" -ForegroundColor Cyan
    $update = Read-Host "Do you want to change the hotkey? (y/n)"
    if ($update.ToLower() -ne "y") {
        Write-Host "Hotkey remains unchanged." -ForegroundColor Yellow
        return
    }
}

# Prompt the user for a new hotkey pattern.
do {
    $pattern = Read-Host "Enter desired hotkey pattern (e.g., Ctrl+Alt+T or Win+Shift+A)"
    $hotkey = Parse-Hotkey -Pattern $pattern
    if (-not $hotkey) {
        Write-Host "Invalid hotkey pattern, please try again." -ForegroundColor Red
    }
} until ($hotkey -ne $null)

# Save (or update) the hotkey pattern in the configuration.
$config.HotkeyPattern = $pattern
Save-Config $config

Write-Host "Hotkey pattern '$pattern' saved successfully to: $configFile" -ForegroundColor Green
