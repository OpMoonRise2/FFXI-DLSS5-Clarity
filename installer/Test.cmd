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
rem The result goes to the helper log, not to this window.
echo Result (from host64\dlss5-feed-host.log):
findstr /C:"--test finished" /C:"--test: neural" "%~dp0..\host64\dlss5-feed-host.log"
echo.
echo Expected: 300/300 evaluates succeeded. Anything else points at the GPU, the driver or the two NVIDIA DLLs.
echo The neural line shows whether the DLSS 5 neural model was created. In the game, host64\OptiScaler.log
echo confirms it: "DLSS-NR cost" lines mean it runs; "create failed ... FeatureNotSupported" means
echo nvngx_dlssnr.dll is the RTX 50-only build (see README.md, Troubleshooting).
pause
