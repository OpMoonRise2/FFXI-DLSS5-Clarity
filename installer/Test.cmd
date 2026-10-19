@echo off
rem Runs the helper self-test (it cannot be started by double-click: that only shows "nothing to run here").
set "HOST=%~dp0..\host64\dlss5-feed-host64.exe"
if not exist "%HOST%" (
  echo host64\dlss5-feed-host64.exe was not found next to this folder.
  echo Run Install.cmd first, from the package folder inside your bootloader folder.
  pause
  exit /b 1
)
"%HOST%" --test
echo.
echo Expected: 300/300 evaluates succeeded. Anything else points at the GPU, the driver or the two NVIDIA DLLs.
echo Whether the DLSS 5 neural pass runs shows in the game, not here: after playing a minute,
echo host64\OptiScaler.log has "DLSS-NR cost" lines. "create failed ... FeatureNotSupported" there means
echo nvngx_dlssnr.dll is the RTX 50-only build (see README.md, Troubleshooting).
pause
