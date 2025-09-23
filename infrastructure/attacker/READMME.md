# 🛠️ Attacker Container (Debian Bookworm Slim)

Ce conteneur est basé sur **`debian:bookworm-slim`** et contient un ensemble d’outils utiles pour les exercices d’attaque sur DVWA et les labos Blueteam.


## 📦 Outils installés

### 🌐 Réseau & diagnostic
- **curl** → tester des requêtes HTTP/HTTPS  
- **wget** → téléchargement de fichiers en ligne  
- **ping (iputils-ping)** → tester la connectivité ICMP  
- **dnsutils** → `dig`, `nslookup` pour résoudre des noms de domaine  
- **net-tools** → anciens outils réseau (`ifconfig`, `netstat`)  
- **netcat-openbsd** → `nc`, établir des connexions TCP/UDP  
- **tcpdump** → capture de trafic réseau (analyse possible dans Wireshark)

### 💻 Services & base de données
- **default-mysql-client** → client MySQL/MariaDB (`mysql`)  
- **sshpass** → automatisation brute force ou scripts SSH  

### 🔍 Scan & reconnaissance
- **nmap** → scan de ports et services  
- **nikto** → scan de vulnérabilités Web  
- **gobuster** → brute force de répertoires/fichiers Web  

### 🔓 Attaques & exploitation
- **sqlmap** → injection SQL automatisée  
- **hydra** → brute force multi-protocole (FTP, SSH, HTTP, etc.)  
- **john (John the Ripper)** → cassage de mots de passe/hachages  

### 🧰 Utilitaires généraux
- **git** → cloner des dépôts d’outils/scripts  
- **tmux** → multiplexeur de terminal (sessions persistantes)  
- **rsyslog** → gestion des logs système  
- **ca-certificates** → certificats SSL/TLS à jour  

### 🐍 Scripting
- **python3** → langage de scripting  
- **python3-pip** → gestionnaire de paquets Python  

---

## 📂 Dossier d’attaques
- Les scripts locaux sont copiés dans **`/opt/attacks/`**  
- Ils sont marqués comme exécutables (`chmod +x`)  
- Le conteneur démarre dans ce dossier par défaut  

---

## ▶️ Commande par défaut
Le conteneur reste actif en arrière-plan avec :  
```bash
sleep infinity
````

Vous pouvez entrer dans le conteneur pour utiliser les outils :

```bash
docker exec -it <lab>_attacker bash
```

---

## ✅ Utilisation type

Exemples :

```bash
# Scan rapide du réseau
nmap -sV 172.30.1.10

# Brute force SSH
hydra -l admin -P rockyou.txt ssh://172.30.1.20

# Injection SQL
sqlmap -u "http://dvwa.lab1.local/vulnerable.php?id=1" --dbs
```