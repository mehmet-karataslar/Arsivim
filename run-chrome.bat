@echo off
REM PusulaKoc - Chrome'da calistir
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run-chrome.ps1"
if errorlevel 1 pause
