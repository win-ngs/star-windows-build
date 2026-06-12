@echo off
where pwsh.exe >nul 2>nul
if %ERRORLEVEL%==0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\STAR-win.ps1" %*
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\STAR-win.ps1" %*
)
exit /b %ERRORLEVEL%
