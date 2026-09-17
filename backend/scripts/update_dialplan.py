import os

dialplan = """[workgo-inbound]
exten => s,1,Answer()
 same => n,Wait(1)
 same => n,Set(CALLER_NUM=${CALLERID(num)})
 same => n,Set(CALL_ID=${EPOCH})

 ; 1. Language Selection Menu in English
 same => n(lang_menu),Playback(workgo/select_language_en)
 same => n,Read(LANG_DIGIT,,1,,,8)

 ; Map digit to language: 1=ta, 2=hi, 3=te, 4=kn, 5=ml, 6=bn, 7=mr, 8=gu, 9=pa, 0/default=en
 same => n,GotoIf($["${LANG_DIGIT}" = "1"]?lang_ta)
 same => n,GotoIf($["${LANG_DIGIT}" = "2"]?lang_hi)
 same => n,GotoIf($["${LANG_DIGIT}" = "3"]?lang_te)
 same => n,GotoIf($["${LANG_DIGIT}" = "4"]?lang_kn)
 same => n,GotoIf($["${LANG_DIGIT}" = "5"]?lang_ml)
 same => n,GotoIf($["${LANG_DIGIT}" = "6"]?lang_bn)
 same => n,GotoIf($["${LANG_DIGIT}" = "7"]?lang_mr)
 same => n,GotoIf($["${LANG_DIGIT}" = "8"]?lang_gu)
 same => n,GotoIf($["${LANG_DIGIT}" = "9"]?lang_pa)
 same => n,Goto(lang_en)

 ; Set Language tags
 same => n(lang_ta),Set(USER_LANG=ta)
 same => n,Goto(collect_details)
 same => n(lang_hi),Set(USER_LANG=hi)
 same => n,Goto(collect_details)
 same => n(lang_te),Set(USER_LANG=te)
 same => n,Goto(collect_details)
 same => n(lang_kn),Set(USER_LANG=kn)
 same => n,Goto(collect_details)
 same => n(lang_ml),Set(USER_LANG=ml)
 same => n,Goto(collect_details)
 same => n(lang_bn),Set(USER_LANG=bn)
 same => n,Goto(collect_details)
 same => n(lang_mr),Set(USER_LANG=mr)
 same => n,Goto(collect_details)
 same => n(lang_gu),Set(USER_LANG=gu)
 same => n,Goto(collect_details)
 same => n(lang_pa),Set(USER_LANG=pa)
 same => n,Goto(collect_details)
 same => n(lang_en),Set(USER_LANG=en)
 same => n,Goto(collect_details)

 same => n(collect_details),NoOp(Selected Language: ${USER_LANG})

 ; Step A: Ask Name and Record
 same => n,Playback(workgo/ask_name_${USER_LANG})
 same => n,Record(/tmp/workgo_${CALL_ID}_name:wav,2,7,k)

 ; Step B: Ask Location and Record
 same => n,Playback(workgo/ask_location_${USER_LANG})
 same => n,Record(/tmp/workgo_${CALL_ID}_location:wav,2,8,k)

 ; Step C: Ask 6-digit Pincode (keypad)
 same => n,Playback(workgo/ask_pincode_${USER_LANG})
 same => n,Read(PINCODE_DIGITS,,6,,,12)

 ; Step D: Ask Trade & Detailed Skills Description (up to 20 seconds)
 same => n,Playback(workgo/ask_trade_desc_${USER_LANG})
 same => n,Record(/tmp/workgo_${CALL_ID}_trade:wav,3,20,k)

 ; Step E: Transcribe via Bhashini and Save to Cloud DB
 same => n,System(python3 /var/lib/asterisk/sounds/workgo/transcribe_and_onboard.py "${CALLER_NUM}" "${USER_LANG}" "${PINCODE_DIGITS}" "/tmp/workgo_${CALL_ID}")

 ; Step F: Confirmation in the chosen language
 same => n,Playback(workgo/registration_done_${USER_LANG})
 same => n,Wait(1)
 same => n,Hangup()

; Route any dialed number or extension directly to the onboarding flow
exten => 1000,1,Goto(workgo-inbound,s,1)
exten => workgo,1,Goto(workgo-inbound,s,1)
exten => 9080262334,1,Goto(workgo-inbound,s,1)
exten => _X.,1,Goto(workgo-inbound,s,1)
"""

conf_path = "/etc/asterisk/extensions.conf"
with open(conf_path, "r") as f:
    content = f.read()

idx = content.find("[workgo-inbound]")
if idx != -1:
    new_content = content[:idx] + dialplan.strip() + "\n"
else:
    new_content = content + "\n" + dialplan.strip() + "\n"

with open(conf_path, "w") as f:
    f.write(new_content)

print("Dialplan updated successfully in /etc/asterisk/extensions.conf")
