#!/bin/bash
URL=${1:-"http://127.0.0.1/DVWA/vulnerabilities/sqli/?id=1&Submit=Submit"}
sqlmap -u "$URL" --batch --level=1 --risk=1 --threads=1 --timeout=10 --technique=BE 2>/dev/null || true
echo "simulate_sqlmap: done (target $URL)"
