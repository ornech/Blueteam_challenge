# 📑 Cheat-sheet commandes (Windows / Linux / SIEM)

---

## 🪟 Windows — commandes essentielles

```cmd
tasklist /FO LIST > C:\temp\tasklist.txt
```

➡️ Lister tous les processus en cours. Vérifier PID + nom.

```cmd
netstat -ano > C:\temp\netstat.txt
```

➡️ Lister connexions réseau (IP locales/distantes, PID).

```cmd
schtasks /query /V /FO LIST > C:\temp\schtasks.txt
```

➡️ Lister les tâches planifiées (chercher persistance).

```cmd
wevtutil epl System C:\temp\System.evtx
```

➡️ Exporter le journal Système en fichier `.evtx`.

```cmd
certutil -hashfile "C:\path\to\file.exe" SHA256 > C:\temp\hash.txt
```

➡️ Calculer le hash SHA256 d’un fichier suspect.

```cmd
netsh interface set interface "Ethernet" admin=DISABLED
```

➡️ Couper l’accès réseau (isoler la machine).

```cmd
robocopy C:\temp \\srv\evidence\inc_YYYYMMDD_HHMM /E /COPYALL /B /R:1 /W:1
```

➡️ Copier toutes les preuves vers le serveur evidence.

---

## 🐧 Linux — commandes essentielles

```bash
sudo mkdir -p /tmp/collect_INC_YYYYMMDD
```

➡️ Créer répertoire de collecte.

```bash
ps aux > /tmp/collect_INC_YYYYMMDD/ps_aux.txt
```

➡️ Lister tous les processus.

```bash
ss -tunap > /tmp/collect_INC_YYYYMMDD/ss.txt
```

➡️ Connexions réseau en cours (TCP/UDP + PID).

```bash
crontab -l > /tmp/collect_INC_YYYYMMDD/crontab.txt
ls -la /etc/cron* > /tmp/collect_INC_YYYYMMDD/cron_dirs.txt
```

➡️ Tâches planifiées utilisateur + système.

```bash
cp /var/log/syslog /tmp/collect_INC_YYYYMMDD/ || true
```

➡️ Copier les logs systèmes (auth.log, messages idem).

```bash
find /usr /home /tmp -type f -mtime -7 -perm /111 -exec ls -l {} \; > /tmp/collect_INC_YYYYMMDD/recent_exec.txt
```

➡️ Fichiers exécutables récents (7 jours).

```bash
tar -czf /tmp/inc_YYYYMMDD.tgz -C /tmp collect_INC_YYYYMMDD
```

➡️ Créer archive compressée des preuves.

```bash
scp /tmp/inc_YYYYMMDD.tgz evidence@10.0.0.5:/srv/evidence/inc_YYYYMMDD/
```

➡️ Transférer archive vers serveur evidence.

---

## 🔍 SIEM / Kibana — requêtes exemples

```kql
http.request.method: "POST" AND destination.ip: "10.0.0.5"
```

➡️ Détecter un exfil HTTP POST.

```kql
event_id: 4688 OR event_id: 4698
```

➡️ Détecter création de processus ou tâche planifiée (Windows).

```kql
NOT destination.ip: "10.0.0.0/8" AND NOT destination.ip: "192.168.0.0/16"
```

➡️ Détecter connexions vers IP externes inhabituelles.

---
