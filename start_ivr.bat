@echo off
title WorkGo IVR Telephony Gateway
color 0A
cls
echo ================================================================
echo           WorkGo - Dial Karya Voice Gateway Launcher           
echo ================================================================
echo.
echo [1/3] Ensuring Asterisk PBX is active in WSL2...
wsl -u root systemctl start asterisk

echo [2/3] Keeping WSL2 awake in background...
start /b "" wsl sleep infinity >nul 2>&1

echo [3/3] Launching SIP Dual Bridge (UDP/TCP + Dynamic Voice RTP)...
echo ================================================================
echo Connect MizuDroid to:
echo   Domain / Server : (Your LAN IP shown below)
echo   Username        : workgo_26089
echo   Password        : workgoSecretPassword123
echo   Dial Extension  : 1000
echo ================================================================
echo.
node backend\scripts\sip_bridge.js
pause
