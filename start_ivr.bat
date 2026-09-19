@echo off
title WorkGo IVR Telephony Gateway
color 0A
cls
echo ================================================================
echo           WorkGo - Dial Karya Voice Gateway Launcher           
echo ================================================================
echo.

echo [1/4] Ensuring Asterisk PBX is active in WSL2...
wsl -u root systemctl start asterisk >nul 2>&1 || wsl -u root service asterisk start >nul 2>&1
start /b "" wsl sleep infinity >nul 2>&1

echo [2/4] Syncing dialplan and reloading Asterisk...
wsl -u root cp -f /mnt/d/WorkGo/backend/asterisk/extensions.conf /etc/asterisk/extensions.conf
wsl -u root bash -c "for i in {1..15}; do asterisk -rx 'core show version' >/dev/null 2>&1 && break || sleep 1; done; asterisk -rx 'dialplan reload'"

echo      Syncing IVR audio files to Asterisk sounds dir (transcoding to PCM 16-bit 8kHz)...
wsl -u root bash -c "mkdir -p /var/lib/asterisk/sounds/workgo && for f in /mnt/d/WorkGo/backend/sounds/*.wav; do name=$(basename \"$f\" .wav); ffmpeg -y -i \"$f\" -ar 8000 -ac 1 -acodec pcm_s16le \"/var/lib/asterisk/sounds/workgo/${name}.wav\" -loglevel quiet 2>/dev/null && echo \"  [OK] ${name}.wav\"; done"
echo      Audio sync complete.


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
echo   Usernames       : workgo_1, workgo_2, workgo_3, workgo_4
echo   Password        : workgoSecretPassword123
echo   Dial Extension  : 1000
echo   (Server IP will be detected and displayed below)
echo ================================================================
echo.
node backend\scripts\sip_bridge.js
pause
