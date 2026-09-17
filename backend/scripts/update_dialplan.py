import os

wsl_extensions_path = r"\\wsl$\Ubuntu\etc\asterisk\extensions.conf"

with open(wsl_extensions_path, "r", encoding="utf-8") as f:
    content = f.read()

# Remove old workgo context if present
marker = "[workgo-inbound]"
if marker in content:
    content = content[:content.find(marker)]

new_dialplan = """[workgo-inbound]
exten => s,1,Answer()
 same => n,Wait(1)
 same => n,Set(CALLER_NUM=${CALLERID(num)})
 ; 1. Welcome spoken in Hindi
 same => n,Playback(workgo/welcome_hi)
 ; 2. Ask Trade (Plumber=1, Electrician=2, Carpenter=3, Painter=4, Other=5)
 same => n,Playback(workgo/ask_trade_hi)
 same => n,Read(TRADE_DIGIT,,1,,,10)
 ; 3. Ask Pincode
 same => n,Playback(workgo/ask_pincode_hi)
 same => n,Read(PINCODE_DIGITS,,6,,,15)
 ; 4. Save to Render Cloud Backend via helper script
 same => n,System(/var/lib/asterisk/sounds/workgo/workgo_onboard.sh "${CALLER_NUM}" "${TRADE_DIGIT}" "${PINCODE_DIGITS}" "hi")
 ; 5. Registration confirmation spoken in Hindi
 same => n,Playback(workgo/registration_done_hi)
 same => n,Wait(1)
 same => n,Hangup()

; Route any dialed number or extension directly to the onboarding flow
exten => 1000,1,Goto(workgo-inbound,s,1)
exten => workgo,1,Goto(workgo-inbound,s,1)
exten => 9080262334,1,Goto(workgo-inbound,s,1)
exten => _X.,1,Goto(workgo-inbound,s,1)
"""

with open(wsl_extensions_path, "w", encoding="utf-8") as f:
    f.write(content.rstrip() + "\n\n" + new_dialplan)

print("Dialplan written successfully to /etc/asterisk/extensions.conf!")
