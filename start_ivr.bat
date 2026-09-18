@echo off
title WorkGo IVR Telephony Gateway
color 0A
cls
echo ================================================================
echo           WorkGo - Dial Karya Voice Gateway Launcher           
echo ================================================================
echo.

echo [1/4] Ensuring Asterisk PBX is active in WSL2...
wsl -u root systemctl start asterisk

echo [2/4] Syncing dialplan and reloading Asterisk...
wsl -u root cp -f /mnt/d/WorkGo/backend/asterisk/extensions.conf /etc/asterisk/extensions.conf
wsl -u root asterisk -rx "dialplan reload"

echo [3/4] Ensuring WorkGo API Backend is running on port 3000...
netstat -ano | findstr :3000 | findstr LISTENING >nul 2>&1
if %errorlevel% neq 0 (
    echo Starting WorkGo API backend in background...
    start "WorkGo API Backend (Port 3000)" cmd /k "cd /d %~dp0backend && node src/index.js"
    timeout /t 3 /nobreak >nul
) else (
    echo WorkGo API backend is already active on port 3000.
)

echo [4/4] Launching SIP Dual Bridge (UDP/TCP + Dynamic Voice RTP)...
echo ================================================================
echo Connect MizuDroid (Up to 4 Mobile Phones):
echo   Domain / Server : 192.168.1.7:5060
echo   Usernames       : workgo_1, workgo_2, workgo_3, workgo_4
echo   Password        : workgoSecretPassword123
echo   Dial Extension  : 1000
echo ================================================================
echo.
node backend\scripts\sip_bridge.js
pause
