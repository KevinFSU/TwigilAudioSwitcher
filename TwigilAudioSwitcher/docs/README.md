# Twigil Audio Switcher

Twigil Audio Switcher is a lightweight PowerShell-based utility designed to simplify the process of cycling through available audio output devices and managing them via a text-based GUI. It also provides the ability to configure a global hotkey for switching audio devices, install the required PowerShell module, and toggle auto-run on startup.

## Features

- **Switch Audio Devices:**  
  Cycle through playback devices using a persistent hotkey listener. The script skips any devices that are marked as "disabled" in the configuration.

- **Global Hotkey Setup:**  
  Configure a global hotkey (e.g., `Ctrl+Alt+T` or `Win+Shift+A`) that triggers the device cycling.

- **Device Management:**  
  Use the GUI to enable or disable individual audio devices. Disabled devices are skipped when cycling.

- **Auto-Run Toggle:**  
  Easily toggle the hotkey service to run at startup via a registry entry.

- **Module Installation:**  
  The GUI can install the `AudioDeviceCmdlets` module if it’s not already installed.

- **Update Device List:**  
  Force a refresh of the audio device list (from the system) and update the JSON configuration accordingly.

## Components

The project is composed of the following scripts:

1. **ChangeAudioOutput.ps1**  
   Cycles through playback devices (skipping disabled devices) and updates the configuration.

2. **SetHotkey.ps1**  
   Prompts the user to set or update the global hotkey pattern, storing it in the configuration file.

3. **StartHotkeyService.ps1**  
   Creates a hidden WinForms listener that waits for the global hotkey press and then executes the device cycling script.

4. **TwigilAudioSwitcherGUI.ps1**  
   Provides a text-based GUI that ties all the functionality together. This script is the only visible interface and can:
   - Install the required module
   - Set the hotkey
   - Start/stop the hotkey listener
   - Manage audio devices (enable/disable)
   - Update the device list
   - Toggle auto-run on startup

## Prerequisites

- **PowerShell 5.1 or later (on Windows)**
- **AudioDeviceCmdlets Module:**  
  The project uses the [AudioDeviceCmdlets](https://www.powershellgallery.com/packages/AudioDeviceCmdlets) module. The GUI script can install this module automatically if it’s not found.

## Setup & Usage

1. **Download/Clone the Repository:**  
   Place all the scripts (`ChangeAudioOutput.ps1`, `SetHotkey.ps1`, `StartHotkeyService.ps1`, and `TwigilAudioSwitcherGUI.ps1`) in the same directory.

2. **Run the GUI:**  
   Open PowerShell, navigate to the directory containing the scripts, and run:
   ```powershell
   .\TwigilAudioSwitcherGUI.ps1
