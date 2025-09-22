docker exec lab1_attacker bash -c '
  curl -s -H "Host: 127.0.0.1" http://lab1_dvwa/setup.php -c /tmp/cookies.txt -o /tmp/setup.html &&
  awk -F"'\''" "/user_token/ {print \$6}" /tmp/setup.html > /tmp/token.txt &&
  echo "[+] Token extrait :" && cat /tmp/token.txt &&
  echo "[+] Envoi de la requête POST setup.php" &&
  curl -s -H "Host: 127.0.0.1" -b /tmp/cookies.txt -d "create_db=Create+%2F+Reset+Database&user_token=$(cat /tmp/token.txt)" http://lab1_dvwa/setup.php -o /tmp/setup_response.html
'

echo "[+] Logs DVWA (via docker logs):"
docker logs lab1_dvwa --tail 20

echo "[+] Vérification des tables DVWA :"
docker exec lab1_attacker mysql -h lab1_mariadb -u dvwa -pdvwa -e "SHOW TABLES IN dvwa;"

