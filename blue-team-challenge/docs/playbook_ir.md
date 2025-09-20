# Playbook IR

**But** : procédure courte et exécutable pour détecter, contenir, analyser, remédier et communiquer lors d’un incident.

> Utilisation : ce playbook est un guide opérationnel. Suivez les étapes dans l’ordre, horodatez tout et ne supprimez rien avant copie sur le serveur dédié au receuil de preuves.

---

## Rôles (résumé)
- **Chef d’incident** : pilote, valide actions, tient le journal, rédige communications.
- **SOC Analyste** : surveille SIEM/logs, identifie IOCs, oriente la collecte.
- **Forensic Analyst** : exécute commandes, collecte preuves, calcule hashes, archive.

---

## Glossaire court
- **IOC** : Indicator of Compromise (IP, hash, PID, nom de tâche).
- **MTTD** : Mean Time To Detect (temps jusqu'à première détection utile).
- **MTTR (contain)** : temps jusqu'à isolement/confinement.

---

## Règles impératives avant toute action
1. Travailler uniquement dans le lab isolé.  
2. Exécuter les commandes avec privilèges nécessaires (admin / sudo).  
3. Créer le dossier de collecte local avant redirections :  
   - Windows : `mkdir C:\temp`  
   - Linux : `mkdir -p /tmp/collect_INC_YYYYMMDD`  
4. Horodater chaque action : `YYYY-MM-DD HH:MM | Rôle | Action | Host | Preuve`  
5. Ne jamais supprimer ou modifier une preuve avant l’avoir copiée en lecture seule sur `\\srv\evidence\inc_YYYYMMDD_HHMM\`.  
6. Toute action technique doit être **validée par le Chef** avant exécution.

---

## Étapes opérationnelles (checklist rapide)

### 0) Initialisation (T0)
- [ ] Chef : créer l’`INCIDENT_ID` → `inc_YYYYMMDD_HHMM`.  
- [ ] Chef : créer dossier evidence central `\\srv\evidence\inc_YYYYMMDD_HHMM\`.  
- [ ] Forensic : créer dossier local (`C:\temp` ou `/tmp/collect_INC_YYYYMMDD`).  
- [ ] SOC : ouvrir Kibana / SIEM, préparer queries basiques.

---

### 1) Détection & Triage (0–60 minutes)
Objectif : confirmer la validité de l’alerte et identifier l’hôte/scope initial.

- SOC : analyser l’alerte → déterminer hôte(s) affecté(s).  
  - Requêtes utiles (Kibana) :  
    - `http.request.method: "POST" AND destination.ip: "10.0.0.5"`  
    - `event_id: 4688 OR event_id: 4698`  
- Si alerte confirmée : Chef décide criticité (Faible / Moyen / Élevé).
- Livrable immédiat : premier enregistrement dans le journal (qui, quoi, quand).

**Checklist Triage**  
- [ ] Horodater réception alerte.  
- [ ] Identifier host(s) compromis (nom/IP).  
- [ ] Définir criticité initiale.  
- [ ] Ouvrir ticket centralisé (référence).  

---

### 2) Containment / Isolation (T+10–60 min)
Objectif : empêcher propagation / exfiltration tout en préservant preuves.

- Chef : valide méthode d’isolation proposée.  
- Forensic : exécute isolation (préférer switch/VLAN ou netsh / Disable-NetAdapter).  
  - Windows (si pas de switch) :  
    ```cmd
    netsh interface set interface "Ethernet" admin=DISABLED
    # ou PowerShell :
    Disable-NetAdapter -Name "Ethernet" -Confirm:$false
    ```
- SOC : monitorer pour vérifier l’arrêt du trafic suspect.

**Checklist Containment**  
- [ ] Hôte isolé (méthode notée).  
- [ ] Blocage d’IP/domaines au firewall si possible.  
- [ ] Surveillance renforcée mise en place (SIEM alerting).

---

### 3) Collecte & Analyse (T+30–180 min)
Objectif : récupérer preuves exploitables et identifier TTP (techniques).

- Forensic : collecter artefacts (exemples Windows) :
```cmd
 tasklist /FO LIST > C:\temp\tasklist.txt
 netstat -ano > C:\temp\netstat.txt
 schtasks /query /V /FO LIST > C:\temp\schtasks.txt
 wevtutil epl System C:\temp\System.evtx
 certutil -hashfile "C:\Users\Public\staged.txt" SHA256 > C:\temp\hash_staged.txt
```

* Linux exemple :

  ```bash
  ps aux > /tmp/collect_INC_YYYYMMDD/ps_aux.txt
  ss -tunap > /tmp/collect_INC_YYYYMMDD/ss.txt
  crontab -l > /tmp/collect_INC_YYYYMMDD/crontab.txt
  cp /var/log/syslog /tmp/collect_INC_YYYYMMDD/ || true
  ```
* SOC : documente IOCs (IP, PID, nom tâche) et fournit preuves associées.
* Forensic : calcule hashes SHA256 pour chaque artefact et stocke dans `hashes_inc_...txt`.

**Checklist Collecte**

* [ ] Tous les artefacts listés sont créés et horodatés.
* [ ] Hashes SHA256 générés.
* [ ] Copie initiale vers `\\srv\evidence\inc_...` (robocopy / scp).
* [ ] Documenter chaque commande exécutée dans le journal.

---

### 4) Eradication & Remédiation

Objectif : supprimer la persistance et restaurer service sécurisé.

* Après validation Chef et sauvegarde des preuves : Forensic supprime persistance :

  ```cmd
  schtasks /Delete /TN "UpdaterTask" /F
  ```
* Appliquer corrections temporaires (blocage IP, désactivation compte compromis).
* Plan de restauration (si besoin : restauration depuis sauvegarde) — validé par Chef.

**Checklist Remédiation**

* [ ] Persistance supprimée (cmd + heure).
* [ ] Services restaurés / redémarrage planifié (si nécessaire).
* [ ] Monitoring intensifié 24–72h.

---

### 5) Communication

Objectif : informer direction et utilisateurs de façon claire et proportionnée.

* **Brief direction** (Chef) — 1 paragraphe : impact, actions, ETA.

  > Exemple : « Un poste utilisateur a été isolé suite à une activité HTTP suspecte vers 10.0.0.5. Nous avons isolé la machine et collecté des preuves ; l’exfiltration semble bloquée. Poursuite de l’analyse — ETA 2h. »
* **Message utilisateurs** (Chef) — 1 phrase simple :

  > Exemple : « Ne cliquez pas sur les pièces jointes suspectes et redémarrez votre poste uniquement sur demande du support. »
* Documenter toutes les communications dans le journal.

---

### 6) Post-mortem & Rapport final

Objectif : tirer des leçons et améliorer les processus.

* Produire **rapport final (1 page)** : contexte, timeline résumée, cause probable, actions réalisées, 3 recommandations prioritaires.
* Mettre à jour le playbook / runbooks si nécessaire.
* Noter les actions de formation (sensibilisation, modifications GPO, règles SIEM).

**Checklist Post-mortem**

* [ ] Rapport final rédigé et horodaté.
* [ ] Leçons apprises listées.
* [ ] Mise à jour des documents (playbook/runbooks).

---

## Livrables obligatoires (nommage recommandé)

* `journal_inc_YYYYMMDD_HHMM.txt` — timeline complète.
* `brief_direction_inc_YYYYMMDD_HHMM.txt` — 1 paragraphe.
* `message_users_inc_YYYYMMDD_HHMM.txt` — consignes utilisateur.
* `tasklist_hostXX_YYYYMMDD_HHMM.txt`, `netstat_hostXX_...`, `schtasks_hostXX_...`, `system_evtx_hostXX_...` — preuves.
* `hashes_inc_YYYYMMDD_HHMM.txt` — hashes.
* `evidence_inc_YYYYMMDD_HHMM.tar.gz` + `evidence_inc_YYYYMMDD_HHMM.sha256` — archive + checksum.
* `rapport_final_inc_YYYYMMDD_HHMM.pdf` — résumé 1 page.

---

## Templates rapides (à copier)

**Entrée journal (modèle)**

```
2025-09-20 09:35 | Alice (SOC) | Détection : HTTP POST vers 10.0.0.5/upload | host-21 | /var/log/elk/alert_789.log
```

**Brief direction (exemple)**

```
Objet : Incident – poste isolé (10.0.0.21)
Résumé : Un poste a envoyé une requête HTTP suspecte vers 10.0.0.5. L'hôte a été isolé et des preuves ont été collectées. Aucun service critique impacté. Actions en cours : analyse forensic et blocage de l'IP. ETA : 2h.
```

**Message utilisateurs (exemple)**

```
Ne pas ouvrir les pièces jointes reçues ce matin. Si votre poste présente un comportement anormal, déconnectez-le du réseau et contactez le support.
```

---

## Commandes utiles (rappel condensé)

**Windows (collecte)**

```cmd
mkdir C:\temp
tasklist /FO LIST > C:\temp\tasklist.txt
netstat -ano > C:\temp\netstat.txt
schtasks /query /V /FO LIST > C:\temp\schtasks.txt
wevtutil epl System C:\temp\System.evtx
certutil -hashfile "C:\Users\Public\staged.txt" SHA256 > C:\temp\hash_staged.txt
robocopy C:\temp \\srv\evidence\inc_YYYYMMDD_HHMM /E /COPYALL /B /R:1 /W:1
```

**Linux (collecte)**

```bash
sudo mkdir -p /tmp/collect_INC_YYYYMMDD
ps aux > /tmp/collect_INC_YYYYMMDD/ps_aux.txt
ss -tunap > /tmp/collect_INC_YYYYMMDD/ss.txt
crontab -l > /tmp/collect_INC_YYYYMMDD/crontab.txt
cp /var/log/syslog /tmp/collect_INC_YYYYMMDD/ || true
tar -czf /tmp/inc_YYYYMMDD.tgz -C /tmp collect_INC_YYYYMMDD
scp /tmp/inc_YYYYMMDD.tgz evidence@10.0.0.5:/srv/evidence/inc_YYYYMMDD/
```

---

## Critères d’évaluation rapide (extrait grille)

* **Détection & triage** : alerte identifiée, host correctement localisé.
* **Containment** : isolement appliqué et vérifié.
* **Collecte & preuves** : fichiers exportés, hashes fournis, archive correcte.
* **Communication** : brief direction clair & message utilisateurs.
* **Journal** : timeline complète et horodatée.

---

### Notes finales

* Adapte les commandes et event\_ids à ton environnement SIEM/Windows.
* Teste toutes les commandes sur tes VM avant la séance.
* Rappelle aux étudiants l’interdiction de toute action destructive.

