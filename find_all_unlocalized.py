import re

def scan_file(filepath):
    print(f"=== SCANNING {filepath} ===")
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    for i, line in enumerate(lines):
        # find string literals inside Text(...) or label: "..." or title: "..."
        matches = re.findall(r'Text\(\s*["\']([^"\']+)["\']', line)
        for m in matches:
            if not m.endswith('.tr()') and not m.startswith('$') and len(m.strip()) > 1 and not m.strip().startswith('x') and '_' not in m:
                print(f"L{i+1}: Text('{m}')")
        
        # Check for hardcoded English in conditional or strings like "Today, ", "Online", "Hello, "
        for kw in ["Hello", "Online", "Offline", "Daily challenge", "Your plan", "ARRIVAL", "Mission", "Enter OTP", "Plumbing", "Standby", "Radar", "OPERATING BASE", "Change", "Refer Artisan", "Glad you're", "Live Dispatch", "Trade Channels", "Radar Coverage", "ONGOING JOB", "Finish current", "Search Radius", "Audio Broadcast", "High-Demand", "Diagnostic Context", "AI Recommended", "Net", "Direct Dispatch"]:
            if kw in line and '.tr()' not in line and '//' not in line:
                print(f"L{i+1} [{kw}]: {line.strip()[:100]}")

scan_file('apps/workgo_karya/lib/src/screens/karya_home_screen.dart')
scan_file('apps/workgo_karya/lib/src/screens/active_job_screen.dart')
scan_file('apps/workgo_karya/lib/src/screens/incoming_requests_screen.dart')
