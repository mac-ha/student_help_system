@echo off
cd /d "%~dp0"
title Student System - http://127.0.0.1:2000

rem If the server is already running, just open the browser.
netstat -ano | findstr /C:":2000 " | findstr /C:"LISTENING" >nul
if not errorlevel 1 (
  echo Student System is already running - opening the browser.
  start "" "http://127.0.0.1:2000"
  timeout /t 2 >nul
  exit /b 0
)

if not exist node_modules\express (
  echo Installing dependencies... this happens once.
  call npm install
)

echo.
echo   ==========================================================
echo    Student System
echo    Portal:    http://127.0.0.1:2000
echo    Lecturer:  http://127.0.0.1:2000/hod.html
echo.
echo    The browser opens automatically in a moment.
echo    Keep this window open. Press Ctrl+C to stop the server.
echo   ==========================================================
echo.

rem Give Node a few seconds, then open the default browser.
start "" /b powershell -NoProfile -WindowStyle Hidden -Command "Start-Sleep -Seconds 3; Start-Process 'http://127.0.0.1:2000'"

node server.js
echo.
echo Server stopped.
pause
