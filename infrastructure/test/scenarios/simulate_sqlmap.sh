#!/bin/bash
# simulate_sqlmap.sh <target_url>
# Usage: ./simulate_sqlmap.sh "http://10.10.1.20/DVWA/vulnerabilities/sqli/?id=1&Submit=Submit"

URL=${1:-"http://10.10.1.20/DVWA/vulnerabilities/sqli/?id=1&Submit=Submit"}
# run with safe options: --level/--risk small; do not dump large data; only detection
sqlmap -u "$URL" --batch --level=1 --risk=1 --threads=2 --technique=BE --answers="follow=Y" --timeout=10
