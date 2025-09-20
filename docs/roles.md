# Fiches de rôle

> Mode d’emploi : chaque rôle doit produire les livrables listés. Toute action technique doit être validée par le Chef d’incident avant exécution. Horodater chaque entrée : `YYYY-MM-DD HH:MM`.

---

## 🎖️ Chef d’incident
**Description (rôle)**  
Le Chef pilote l’incident : il fixe les priorités, prend les décisions (confinement, remédiation), valide les actions techniques demandées par SOC/Forensic et rédige les messages aux parties prenantes. Il tient le **journal d’incident** (timeline) et s’assure que toutes les preuves sont copiées dans `\\srv\evidence\inc_YYYYMMDD_HHMM\`.

**Attendus / Livrables**
- `journal_inc_YYYYMMDD_HHMM.txt` — timeline complète (obligatoire).  
- `brief_direction_inc_YYYYMMDD_HHMM.txt` — 1 paragraphe clair, non technique.  
- `message_users_inc_YYYYMMDD_HHMM.txt` — consignes simples pour les utilisateurs.  
- Validation écrite (ligne dans le journal) pour chaque action technique exécutée par Forensic.

**Exemples concrets**
- Entrée de journal (à coller) :  
```

2025-09-20 09:35 | Bob (Chef) | Décision : isoler l'hôte 10.0.0.21 ; raison : alerte SIEM confirmée | host-21

```
- Brief direction (exemple) :  
```

Objet : Incident – poste isolé (10.0.0.21)
Résumé : Un poste a généré du trafic HTTP suspect vers 10.0.0.5. L’hôte a été isolé et une analyse est en cours. Actions : collecte de preuves et blocage IP. ETA : 2h.

```
- Règle opérationnelle : **ne pas autoriser** une suppression ou un redémarrage sans entrée explicite dans le journal signée par le Chef.

---

## 👁️ SOC Analyste (Détection / Monitoring)
**Description (rôle)**  
Le SOC (Security Information and Event Management → outil d’analyse des logs) recherche et valide les alertes, identifie les **IOC** (Indicators of Compromise → indicateurs de compromission : IP, hash, PID, nom de tâche), et oriente la collecte en indiquant **où** et **quoi** chercher.

**Attendus / Livrables**
- `iocs_list_YYYYMMDD_HHMM.txt` — liste d’IOCs identifiés, format : type | valeur | preuve (fichier/log).  
- `explication_ioc_YYYYMMDD_HHMM.txt` — 1 phrase d’explication par IOC (pour le Chef / Forensic).  
- Entrées de journal indiquant la source de l’alerte et l’heure (ex. : Kibana / SIEM).

**Commandes / Requêtes utiles**
- Kibana (ex.) :  
```

http.request.method: "POST" AND destination.ip: "10.0.0.5"

```
- Recherche d’événements Windows (ex.) :  
```

event\_id: 4688 OR event\_id: 4698

```

**Exemples concrets**
- IOC list (extrait) :
```

type: ip | value: 10.0.0.5 | preuve: kibana\_log\_20250920\_0930.json
type: pid | value: 1234 | preuve: netstat\_host21\_20250920\_0940.txt

```
- Explication (ex.) :
```

PID 1234 = powershell.exe a initié un HTTP POST vers 10.0.0.5 (preuve: netstat + tasklist).

```
- Entrée de journal (SOC) :
```

2025-09-20 09:30 | Alice (SOC) | Alerte SIEM : POST vers 10.0.0.5/upload détectée | host-21 | /var/log/elk/alert\_789.log

````

---

## 🛠️ Forensic Analyst (Collecte / Commandes)
**Description (rôle)**  
Le Forensic exécute les commandes de collecte sur l’hôte compromis, crée des artefacts lisibles, calcule les hashes (empreintes numériques), et transfère les preuves vers le serveur evidence. Il doit documenter chaque commande exécutée dans le journal (qui, quoi, quand).

**Attendus / Livrables**
- Fichiers de preuve exportés (nommage recommandé) :
- `tasklist_hostXX_YYYYMMDD_HHMM.txt`
- `netstat_hostXX_YYYYMMDD_HHMM.txt`
- `schtasks_hostXX_YYYYMMDD_HHMM.txt`
- `system_evtx_hostXX_YYYYMMDD_HHMM.evtx` (si possible)
- `hashes_inc_YYYYMMDD_HHMM.txt` — SHA256 de chaque artefact.  
- Copie sur le serveur evidence : `\\srv\evidence\inc_YYYYMMDD_HHMM\...` et confirmation dans le journal.  
- `evidence_inc_YYYYMMDD_HHMM.tar.gz` + `evidence_inc_YYYYMMDD_HHMM.sha256` (peut être fait côté serveur).

**Commandes utiles (à exécuter seulement après validation Chef)**
- Windows (cmd / PowerShell) :
```cmd
mkdir C:\temp
tasklist /FO LIST > C:\temp\tasklist_host21_20250920_0940.txt
netstat -ano > C:\temp\netstat_host21_20250920_0940.txt
schtasks /query /V /FO LIST > C:\temp\schtasks_host21_20250920_0940.txt
wevtutil epl System C:\temp\System_host21_20250920_0940.evtx
certutil -hashfile C:\Users\Public\staged.txt SHA256 > C:\temp\hashes_host21_20250920_0940.txt
robocopy C:\temp \\srv\evidence\inc_20250920_0930 /E /COPYALL /B /R:1 /W:1
````

* Linux (shell) :

  ```bash
  sudo mkdir -p /tmp/collect_YYYYMMDD_HHMM
  ps aux > /tmp/collect_.../ps_aux.txt
  ss -tunap > /tmp/collect_.../ss.txt
  crontab -l > /tmp/collect_.../crontab.txt
  cp /var/log/syslog /tmp/collect_.../ || true
  sha256sum /tmp/collect_.../* > /tmp/collect_.../hashes.txt
  tar -czf /tmp/inc_YYYYMMDD_HHMM.tgz -C /tmp collect_...
  scp /tmp/inc_YYYYMMDD_HHMM.tgz evidence@10.0.0.5:/srv/evidence/inc_YYYYMMDD_HHMM/
  ```

**Exemples concrets**

* Fichier `tasklist_host21_20250920_0940.txt` (extrait) :

  ```
  Image Name: powershell.exe
  PID: 1234
  Session Name: Console
  ```
* Entrée de journal (Forensic) :

  ```
  2025-09-20 09:38 | Claire (Forensic) | tasklist & netstat collectés ; copies vers \\srv\evidence\inc_20250920_0930\ ; hashes générés
  ```
* Ligne de validation (Chef requise avant suppression) :

  ```
  2025-09-20 10:05 | Bob (Chef) | Validation suppression UpdaterTask autorisée après copie des preuves
  ```

---

## ✅ Checklist rapide par rôle (à cocher pendant l’exercice)

### Chef

* [ ] Créer `INCIDENT_ID` et dossier evidence.
* [ ] Tenir le journal (toutes les 5–10 minutes minimum).
* [ ] Rédiger brief direction + message utilisateurs.
* [ ] Valider suppression/purger persistance.

### SOC

* [ ] Lancer requêtes SIEM/Kibana pertinentes.
* [ ] Documenter IOCs + preuves associées.
* [ ] Communiquer les priorités au Chef.

### Forensic

* [ ] Créer dossier local de collecte.
* [ ] Exécuter commandes de collecte après validation.
* [ ] Générer hashes et copier preuves vers `\\srv\evidence\...`.
* [ ] Produire archive et checksum (ou indiquer chemin si fait par le serveur).

---

## ⛔ Règles strictes (rappel)

* **Ne jamais supprimer ou modifier** une preuve avant copie en lecture seule.
* **Toute commande destructrice est interdite.**
* **Horodater** chaque action : format `YYYY-MM-DD HH:MM | Rôle | Action`.
* Si un rôle est bloqué, il doit informer immédiatement le Chef (entrée dans le journal).

---

## Annexes utiles (à coller)

* Modèle d’entrée de journal :

  ```
  2025-09-20 09:35 | Alice (SOC) | Détection : HTTP POST vers 10.0.0.5/upload | host-21 | /var/log/elk/alert_789.log
  ```
* Exemple de nommage des fichiers de preuve :

  * `tasklist_host21_20250920_0940.txt`
  * `netstat_host21_20250920_0940.txt`
  * `system_evtx_host21_20250920_0942.evtx`
  * `hashes_inc_20250920_0930.txt`

```
