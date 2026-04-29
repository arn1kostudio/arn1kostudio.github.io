@echo off
setlocal

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-local-site.ps1"

echo.
echo Local preview was closed.
pause
