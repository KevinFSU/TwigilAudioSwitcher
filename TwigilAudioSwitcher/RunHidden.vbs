Dim objFSO, scriptDir, filePath, objShell

Set objFSO = CreateObject("Scripting.FileSystemObject")

scriptDir = objFSO.GetParentFolderName(WScript.ScriptFullName)

filePath = objFSO.BuildPath(scriptDir, "bin\StartHotkeyService.ps1")

Set objShell = CreateObject("WScript.Shell")

objShell.Run "powershell.exe -ExecutionPolicy Bypass -NoProfile -File """ & filePath & """", 0, False
