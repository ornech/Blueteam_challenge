#!/bin/bash
# simulate_web_upload.sh <upload_url> <file_field> <filename>
# Usage: ./simulate_web_upload.sh http://10.10.1.20/DVWA/vulnerabilities/upload/ uploaded marker.php

UPLOAD_URL=${1:-"http://10.10.1.20/DVWA/vulnerabilities/upload/"}
FIELD=${2:-"uploaded"}
FNAME=${3:-marker.php}

cat > /tmp/${FNAME} <<'EOF'
<?php
echo "MARKER_OK";
?>
EOF

curl -s -F "${FIELD}=@/tmp/${FNAME}" "$UPLOAD_URL" -o /tmp/upload_resp.html
echo "uploaded /tmp/${FNAME} to $UPLOAD_URL"
