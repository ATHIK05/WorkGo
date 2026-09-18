#!/usr/bin/env python3
"""
Writes the corrected WorkGo extensions.conf to /etc/asterisk/extensions.conf.
This sidesteps shell quoting/interpolation issues.
"""
content = r"""
; ============================================================================
; WorkGo IVR Dialplan - /etc/asterisk/extensions.conf
;
; KEY ARCHITECTURE FIX:
;   Every inbound call first calls /api/ivr/voice/inbound to determine
;   routing. Verified workers get toggle_menu. New callers get onboarding.
;   Uses System() + /usr/bin/curl to call backend (func_curl.so not available)
;   and FILE() to read the JSON response.
; ============================================================================

[globals]
BACKEND_URL=http://localhost:3000

[workgo-inbound]
exten => s,1,Answer()
 same => n,Wait(1)
 same => n,Set(CALLER_NUM=${CALLERID(num)})
 same => n,Set(CALL_ID=${EPOCH})
 same => n,Set(RESP_FILE=/tmp/workgo_inbound_${CALL_ID}.json)

 ; Ask backend who this caller is
 same => n,System(/usr/bin/curl -s -X POST http://localhost:3000/api/ivr/voice/inbound -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'caller=${CALLER_NUM}' -o ${RESP_FILE} --connect-timeout 5 --max-time 8)
 same => n,NoOp(curl /inbound done)

 ; Read response file
 same => n,Set(INBOUND_RESP=${FILE(${RESP_FILE})})
 same => n,NoOp(Backend: ${INBOUND_RESP})

 ; Parse action - JSON format is {"action":"toggle_menu",...}
 same => n,Set(IVR_ACTION=${CUT(INBOUND_RESP,action\":"",2)})
 same => n,Set(IVR_ACTION=${CUT(IVR_ACTION,""",1)})
 same => n,NoOp(IVR_ACTION=${IVR_ACTION})

 ; Parse language
 same => n,Set(WORKER_LANG=${CUT(INBOUND_RESP,language\":"",2)})
 same => n,Set(WORKER_LANG=${CUT(WORKER_LANG,""",1)})
 same => n,GotoIf($["${WORKER_LANG}" = ""]?set_default_lang)
 same => n,Goto(route_check)
 same => n(set_default_lang),Set(WORKER_LANG=hi)

 ; Route by action
 same => n(route_check),GotoIf($["${IVR_ACTION}" = "toggle_menu"]?toggle_menu)
 same => n,GotoIf($["${IVR_ACTION}" = "pending_kyc"]?pending_kyc)
 same => n,Goto(onboarding)

 same => n(toggle_menu),NoOp(Verified worker - toggle menu lang=${WORKER_LANG})
 same => n,Playback(workgo/toggle_menu_${WORKER_LANG})
 same => n,WaitExten(10)
 same => n,Hangup()

 same => n(pending_kyc),NoOp(Worker awaiting Peer KYC)
 same => n,Playback(workgo/pending_kyc_${WORKER_LANG})
 same => n,Wait(1)
 same => n,Hangup()

 same => n(onboarding),NoOp(New caller - onboarding flow)
 same => n(lang_menu),Playback(workgo/select_language_en)
 same => n,Read(LANG_DIGIT,,1,,,8)
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
 same => n(collect_details),NoOp(Language: ${USER_LANG})
 same => n,Playback(workgo/ask_name_${USER_LANG})
 same => n,Record(/tmp/workgo_${CALL_ID}_name:wav,2,7,k)
 same => n,Playback(workgo/ask_location_${USER_LANG})
 same => n,Record(/tmp/workgo_${CALL_ID}_location:wav,2,8,k)
 same => n,Playback(workgo/ask_pincode_${USER_LANG})
 same => n,Read(PINCODE_DIGITS,,6,,,12)
 same => n,Playback(workgo/ask_trade_desc_${USER_LANG})
 same => n,Record(/tmp/workgo_${CALL_ID}_trade:wav,3,20,k)
 same => n,System(python3 /var/lib/asterisk/sounds/workgo/transcribe_and_onboard.py "${CALLER_NUM}" "${USER_LANG}" "${PINCODE_DIGITS}" "/tmp/workgo_${CALL_ID}")
 same => n,Playback(workgo/registration_done_${USER_LANG})
 same => n,Wait(1)
 same => n,Hangup()

exten => 1,1,NoOp(Worker ${CALLER_NUM} going ONLINE)
 same => n,System(/usr/bin/curl -s -X POST http://localhost:3000/api/ivr/voice/toggle-status -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'caller=${CALLER_NUM}' -d 'status=online' -o /tmp/workgo_toggle_${EPOCH}.json --connect-timeout 5)
 same => n,GotoIf($["${WORKER_LANG}" != ""]?play_online)
 same => n,Set(WORKER_LANG=hi)
 same => n(play_online),Playback(workgo/online_confirmed_${WORKER_LANG})
 same => n,Wait(1)
 same => n,Hangup()

exten => 2,1,NoOp(Worker ${CALLER_NUM} going OFFLINE)
 same => n,System(/usr/bin/curl -s -X POST http://localhost:3000/api/ivr/voice/toggle-status -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'caller=${CALLER_NUM}' -d 'status=offline' -o /tmp/workgo_toggle_${EPOCH}.json --connect-timeout 5)
 same => n,GotoIf($["${WORKER_LANG}" != ""]?play_offline)
 same => n,Set(WORKER_LANG=hi)
 same => n(play_offline),Playback(workgo/offline_confirmed_${WORKER_LANG})
 same => n,Wait(1)
 same => n,Hangup()

exten => 1000,1,Goto(workgo-inbound,s,1)
exten => workgo,1,Goto(workgo-inbound,s,1)
exten => 9080262334,1,Goto(workgo-inbound,s,1)
exten => _X.,1,Goto(workgo-inbound,s,1)
exten => t,1,Hangup()
exten => i,1,Hangup()

[workgo-booking-alert]
exten => s,1,Answer()
 same => n,Wait(1)
 same => n,Playback(${BOOKING_AUDIO})
 same => n,WaitExten(15)
exten => 1,1,NoOp(Worker accepting booking ${BOOKING_ID})
 same => n,System(/usr/bin/curl -s -X POST http://localhost:3000/api/ivr/voice/claim-booking -H 'Content-Type: application/x-www-form-urlencoded' -d 'caller=${WORKER_PHONE}&bookingId=${BOOKING_ID}' -o /tmp/workgo_claim_${BOOKING_ID}.json --connect-timeout 5)
 same => n,Playback(workgo/booking_confirmed_en)
 same => n,Wait(1)
 same => n,Hangup()
exten => 2,1,Playback(workgo/booking_declined_en)
 same => n,Wait(1)
 same => n,Hangup()
exten => t,1,Hangup()
exten => i,1,Hangup()

[workgo-booking-taken]
exten => s,1,Answer()
 same => n,Playback(workgo/booking_taken_en)
 same => n,Hangup()

[workgo-otp-flash]
exten => s,1,Answer()
 same => n,Wait(1)
 same => n,Playback(${OTP_AUDIO})
 same => n,Wait(1)
 same => n,Hangup()
""".lstrip()

with open("/etc/asterisk/extensions.conf", "w") as f:
    f.write(content)

print("SUCCESS: extensions.conf written")
