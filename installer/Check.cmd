@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup.ps1" -Action Check %*
pause
