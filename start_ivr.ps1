Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "          WorkGo - Dial Karya Voice Gateway Launcher            " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[1/3] Ensuring Asterisk PBX is active in WSL2..." -ForegroundColor Yellow
wsl -u root systemctl start asterisk

Write-Host "[2/3] Keeping WSL2 awake in background..." -ForegroundColor Yellow
Start-Process -NoNewWindow -FilePath "wsl" -ArgumentList "sleep infinity"

Write-Host "[3/3] Launching SIP Dual Bridge (UDP/TCP + Voice RTP)..." -ForegroundColor Yellow
Write-Host ""
node backend\scripts\sip_bridge.js
