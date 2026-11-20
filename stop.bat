@echo off
title Stop Student System
setlocal enabledelayedexpansion
set found=0
for /f "tokens=5" %%p in ('netstat -ano ^| findstr /C:":2000 " ^| findstr /C:"LISTENING"') do (
  echo Stopping server process %%p ...
  taskkill /PID %%p /F >nul 2>&1
  set found=1
)
if "!found!"=="0" echo The server is not running.
timeout /t 2 >nul
