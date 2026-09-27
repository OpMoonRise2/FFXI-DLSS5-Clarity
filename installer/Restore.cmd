@echo off
set /p clarity_backup=Paste the full FFXI-Clarity-backup folder path: 
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup.ps1" -Action Restore -Backup "%clarity_backup%" %*
pause
