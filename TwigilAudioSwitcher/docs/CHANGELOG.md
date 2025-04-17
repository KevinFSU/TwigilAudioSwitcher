# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-04-16
### Added
- Initial release of Twigil Audio Switcher.
- Text-based GUI (`TwigilAudioSwitcherGUI.ps1`) that provides the following functionality:
  - Installation of the `AudioDeviceCmdlets` module.
  - Setting a global hotkey via `SetHotkey.ps1`.
  - Starting and stopping the persistent hotkey listener (`StartHotkeyService.ps1`).
  - Managing audio playback devices—enabling/disabling devices through the JSON configuration.
  - Updating the audio device list via a refresh option.
  - Toggling auto-run of the hotkey service at startup.
- Global hotkey support using a hidden WinForms listener.
- JSON-based configuration (`DeviceList.json`) with support for a "Disabled" flag per device.
- Process launching improvements using hidden window style (via `ProcessStartInfo`) to ensure no console window is visible during execution.

### Fixed
- Fixed exit behavior in the GUI so that the application terminates properly.
- Adjusted process call parameters in the GUI and hotkey service to ensure that no additional windows are spawned.
- Improved JSON processing to rebuild device objects as mutable `[PSCustomObject]` for proper property modification.

## Future Improvements
- Consider an installer package for simplified deployment.
- Add more comprehensive error handling and logging.
- Enhance UI feedback and visual improvements in the GUI.
- Explore cross-platform compatibility if there is demand.

