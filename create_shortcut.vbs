Set WshShell = CreateObject("WScript.Shell")
desktopPath = WshShell.SpecialFolders("Desktop")
shortcutPath = desktopPath & "\CineAI.lnk"

Set shortcut = WshShell.CreateShortcut(shortcutPath)
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)

shortcut.TargetPath = "wscript.exe"
shortcut.Arguments = """" & scriptDir & "\launch_cineai.vbs"""
shortcut.WorkingDirectory = scriptDir
shortcut.Description = "CineAI - Film Takip ve Yapay Zeka Oneri Uygulamasi"
shortcut.IconLocation = "shell32.dll, 115"
shortcut.Save

WScript.Echo "SUCCESS"
