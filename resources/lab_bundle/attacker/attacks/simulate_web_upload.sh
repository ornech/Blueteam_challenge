#!/bin/bash
UPLOAD_URL=${1:-"http://127.0.0.1/DVWA/vulnerabilities/upload/"}
FIELD=${2:-"uploaded"}
FNAME=${3:-marker.php}
cat > /tmp/${FNAME} <<'EOF'
<?php
echo "MARKER_OK";
?>
EOF
curl -s -F "${FIELD}=@/tmp/${FNAME}" "$UPLOAD_URL" -o /tmp/upload_resp.html || true
echo "simulate_web_upload: uploaded /tmp/${FNAME} to $UPLOAD_URL"
