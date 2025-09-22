#!/bin/bash

# Usage: ./init_dvwa.sh lab1
LAB=$1

if [ -z "$LAB" ]; then
  echo "Usage: $0 <labname> (ex: lab1, lab2, ...)"
  exit 1
fi

DVWA="${LAB}_dvwa"
MARIADB="${LAB}_mariadb"
ATTACKER="${LAB}_attacker"

echo "[+] Initialisation de DVWA sur $LAB..."

docker exec "$ATTACKER" bash -c "
  echo '[*] Requête GET pour récupérer le token...' &&
  curl -s -H "Host: 127.0.0.1" http://$DVWA/setup.php -c /tmp/cookies.txt -o /tmp/setup.html 
  
  echo '[*] Extraction du token...' &&
  awk -F\"\\'\" '/user_token/ {print \$6}' /tmp/setup.html > /tmp/token.txt

  TOKEN=\$(cat /tmp/token.txt)
  echo \"[+] Token extrait : \$TOKEN\"

  echo '[*] Envoi de la requête POST pour setup.php...' &&
  curl -s -b /tmp/cookies.txt -d \"create_db=Create+%2F+Reset+Database&user_token=\$TOKEN\" http://$DVWA/setup.php -o /tmp/setup_response.html

  echo '[+] Tables créées dans la base de données :' &&
  mysql -h $MARIADB -u dvwa -pdvwa -e 'SHOW TABLES IN dvwa;'
"
