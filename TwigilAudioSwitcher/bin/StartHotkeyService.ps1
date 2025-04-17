# StartHotkeyService.ps1
# ===============================================
# This script starts a persistent hotkey listener that reads the
# global hotkey pattern from the configuration file (DeviceList.json)
# and remains running. When the specified hotkey is pressed, the script
# launches ChangeAudioOutput.ps1 to cycle the audio output device.
#
# Requirements: DeviceList.json and ChangeAudioOutput.ps1 must reside in the same folder.
# ===============================================

$ErrorActionPreference = "Stop"

# Determine the directory for the configuration.
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$configFile = Join-Path $scriptDir "DeviceList.json"
$changeScript = Join-Path $scriptDir "ChangeAudioOutput.ps1"

# Function to load configuration.
function Load-Config {
    if (Test-Path $configFile) {
        $json = Get-Content $configFile -Raw | ConvertFrom-Json
        if (-not $json.Devices) { $json.Devices = @() }
        if (-not $json.CurrentIndex) { $json.CurrentIndex = 0 }
        if (-not $json.HotkeyPattern) { $json.HotkeyPattern = "" }
        return $json
    }
    else {
        Write-Host "Configuration file not found: $configFile" -ForegroundColor Red
        exit 1
    }
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

# Load configuration to retrieve the hotkey pattern.
$config = Load-Config
if ([string]::IsNullOrWhiteSpace($config.HotkeyPattern)) {
    Write-Host "Hotkey pattern is not configured. Run SetHotkey.ps1 first." -ForegroundColor Red
    exit 1
}

$pattern = $config.HotkeyPattern
$hotkey = Parse-Hotkey -Pattern $pattern
if (-not $hotkey) {
    Write-Host "Failed to parse the hotkey pattern from configuration." -ForegroundColor Red
    exit 1
}

Write-Host "Using hotkey pattern: '$pattern' (Modifiers: $($hotkey.Modifiers), VKey: $($hotkey.VKey))" -ForegroundColor Cyan

# Ensure the System.Windows.Forms assembly is loaded.
Add-Type -AssemblyName System.Windows.Forms

# Define a hidden WinForms form to capture WM_HOTKEY messages.
Add-Type -ReferencedAssemblies "System.Windows.Forms.dll" -TypeDefinition @"
using System;
using System.Windows.Forms;
using System.Runtime.InteropServices;
public class HotkeyForm : Form {
    public event EventHandler HotkeyPressed;
    protected override void WndProc(ref Message m) {
        const int WM_HOTKEY = 0x0312;
        if(m.Msg == WM_HOTKEY && this.HotkeyPressed != null) {
            this.HotkeyPressed(this, EventArgs.Empty);
        }
        base.WndProc(ref m);
    }
}
"@

# Import native methods for hotkey registration.
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class HotKeyNativeMethods {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
}
"@

# Create an instance of the hidden WinForms window.
$form = New-Object HotkeyForm
$form.Text = "TwigilAudioSwitcher Listener"
$form.WindowState = 'Minimized'
$form.ShowInTaskbar = $false

$hotkeyID = 1
$registered = [HotKeyNativeMethods]::RegisterHotKey($form.Handle, $hotkeyID, $hotkey.Modifiers, $hotkey.VKey)
if (-not $registered) {
    $errCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    Write-Host "Failed to register hotkey '$pattern' (Error code: $errCode). Exiting persistent mode." -ForegroundColor Red
    exit 1
}
Write-Host "Hotkey '$pattern' successfully registered. Listening for key press..." -ForegroundColor Green

# Add a hotkey event handler.
$form.Add_HotkeyPressed({
    Write-Host "Hotkey pressed! Executing ChangeAudioOutput.ps1..." -ForegroundColor Yellow
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$changeScript`""
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    Write-Host "ChangeAudioOutput.ps1 launched." -ForegroundColor Cyan
})

Write-Host "Persistent hotkey service is running." -ForegroundColor Magenta
[System.Windows.Forms.Application]::Run($form)

[HotKeyNativeMethods]::UnregisterHotKey($form.Handle, $hotkeyID)
