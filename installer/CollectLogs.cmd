@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0CollectLogs.ps1" %*
pause
