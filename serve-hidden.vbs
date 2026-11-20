' Starts the Student System server with no visible window.
' Safe to run when the server is already up: it checks the port first.
Option Explicit

Dim sh, fso, dir, probe

Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)

Set probe = sh.Exec("cmd /c netstat -ano | findstr "":2000 "" | findstr ""LISTENING""")
Do While probe.Status = 0
  WScript.Sleep 100
Loop

If probe.ExitCode = 0 Then
  WScript.Quit 0
End If

If Not fso.FolderExists(dir & "\logs") Then
  fso.CreateFolder(dir & "\logs")
End If

sh.Run "cmd /c cd /d """ & dir & """ && node server.js >> logs\server.log 2>&1", 0, False
