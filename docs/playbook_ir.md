# Playbook IR

**But** : procédure courte et exécutable pour détecter, contenir, analyser, remédier et communiquer lors d’un incident.

> Utilisation : ce playbook est un guide opérationnel. Suivez les étapes dans l’ordre, horodatez tout et ne supprimez rien avant copie sur le serveur dédié au receuil de preuves.

---

## Rôles (résumé)
- **Chef d’incident** : pilote, valide actions, tient le journal, rédige communications.
- **SOC Analyste** : surveille SIEM/logs, identifie IOCs, oriente la collecte.
- **Forensic Analyst** : exécute commandes, collecte preuves, calcule hashes, archive.

---

## Phase 1 – Détection (Detection)

* **But** : Identifier si l’alerte est réelle.
* **Actions** :

  * SOC Analyste (détection) → lancer requête SIEM (Security Information and Event Management, outil d’analyse des logs) :

    ```kql
    http.request.method: "POST" AND destination.ip: "10.0.0.5"
    ```
  * Chef d’incident → évaluer la **criticité** (Faible/Moyen/Élevé).
* **Livrables** :

  * Journal d’incident (Incident Log → **chronologie des actions**)
  * Liste d’IOC (Indicator of Compromise → **indicateurs de compromission**, ex. IP, PID, hash).

---

## Phase 2 – Confinement (Containment)

* **But** : Isoler la machine compromise pour éviter propagation ou exfiltration (fuite de données).
* **Actions** :

  * Forensic Analyst (collecte) → exécuter :

    ```cmd
    netsh interface set interface "Ethernet" admin=DISABLED
    ```

    (→ couper la carte réseau, équivalent débrancher le câble)
  * SOC Analyste → vérifier dans le SIEM que le trafic suspect a cessé.
* **Livrables** :

  * Entrée horodatée dans le journal.
  * Capture netstat avant/après confinement.

---

## Phase 3 – Collecte de preuves (Forensic Collection)

* **But** : Sauvegarder les preuves (artifacts → **artefacts techniques**) pour analyse ultérieure.
* **Actions** :

  * Forensic Analyst → exécuter `tasklist`, `netstat`, `schtasks`, `wevtutil`, calculer hash (empreinte numérique SHA256).
  * Transférer preuves sur `\\srv\evidence\inc_YYYYMMDD_HHMM`.
* **Livrables** :

  * Fichiers collectés (`tasklist.txt`, `netstat.txt`, `.evtx`).
  * Hashes (`hashes_inc_...txt`).
  * Archive finale `.tar.gz` + checksum (somme de contrôle).

---

## Phase 4 – Éradication (Eradication)

* **But** : Supprimer la persistance (persistence → **mécanisme de survie du malware**).
* **Actions** :

  * Forensic Analyst → après validation Chef, exécuter :

    ```cmd
    schtasks /Delete /TN "UpdaterTask" /F
    ```
* **Livrables** :

  * Journal : suppression consignée.
  * Capture avant/après (preuve que la tâche n’existe plus).

---

## Phase 5 – Communication

* **But** : Informer clairement la direction et les utilisateurs.
* **Actions** :

  * Chef → rédige brief direction (executive summary → **résumé exécutif**) et message utilisateurs (simple et compréhensible).
* **Livrables** :

  * Fichier `brief_direction.txt`.
  * Fichier `message_users.txt`.

---

## Phase 6 – Post-mortem (Retour d’expérience)

* **But** : Tirer les leçons de l’incident.
* **Actions** :

  * Toute l’équipe → rédige rapport final (root cause analysis → **analyse de cause racine** + recommandations).
* **Livrables** :

  * Rapport final (1 page PDF).
  * Liste des recommandations.
