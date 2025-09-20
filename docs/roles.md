# 📑 Fiches de rôle — Exercice Blue Team (BTS SIO)

> Toute action doit être validée par le Chef avant exécution.  
> Chaque rôle doit produire ses livrables, horodatés et copiés dans `\\srv\evidence\inc_YYYYMMDD_HHMM\`.  
> Format journal : `YYYY-MM-DD HH:MM | Rôle | Action | Host | Preuve`.


## 🎖️ Chef d’incident

### Description
Pilote de l’équipe. Donne les priorités, valide chaque action, tient le journal central et rédige les communications vers la direction et les utilisateurs.

### Responsabilités
- Valider toutes les actions proposées par SOC et Forensic.  
- Tenir le **journal d’incident** (timeline complète).  
- Rédiger le **brief direction** (1 paragraphe non technique).  
- Rédiger le **message utilisateurs** (1 paragraphe clair).  
- Vérifier que toutes les preuves sont copiées dans le dossier evidence.

### Livrables attendus
- `journal_inc_YYYYMMDD_HHMM.txt`  
- `brief_direction_inc_YYYYMMDD_HHMM.txt`  
- `message_users_inc_YYYYMMDD_HHMM.txt`

### Exemples
- Journal :  
```

2025-09-20 09:35 | Bob (Chef) | Décision : isoler host-21 suite alerte SIEM confirmée

```
- Brief direction :  
```

Objet : Incident – poste isolé (10.0.0.21)
Résumé : Un poste a généré du trafic HTTP suspect vers 10.0.0.5. L’hôte a été isolé et une analyse est en cours. Aucun service critique n’est impacté.

```
- Message utilisateurs :  
```

Ne cliquez pas sur les pièces jointes suspectes. Si votre poste a un comportement étrange, déconnectez-le et contactez le support.

```

---

## 👁️ SOC Analyste (Détection / Monitoring)

### Description
Analyse les journaux dans le SIEM (Security Information and Event Management → outil d’analyse des logs). Identifie les IOC (Indicators of Compromise → indicateurs de compromission : IP, PID, hash, nom de tâche) et oriente le Forensic.

### Responsabilités
- Surveiller SIEM/Kibana et logs.  
- Identifier et documenter les IOC.  
- Transmettre au Chef les anomalies détectées.  
- Vérifier que les preuves collectées correspondent aux IOC.

### Livrables attendus
- `iocs_list_YYYYMMDD_HHMM.txt` (type | valeur | preuve)  
- `explication_ioc_YYYYMMDD_HHMM.txt` (1 phrase d’explication par IOC)

### Exemples
- Journal (SOC) :  
```

2025-09-20 09:30 | Alice (SOC) | Détection : HTTP POST vers 10.0.0.5/upload | host-21 | kibana\_alert\_789.log

```
- IOC list :  
```

type: ip | value: 10.0.0.5 | preuve: kibana\_20250920.json
type: pid | value: 1234 | preuve: netstat\_host21\_20250920.txt

```
- Explication :  
```

PID 1234 = powershell.exe a initié un HTTP POST vers 10.0.0.5 (preuve: netstat + tasklist).

````

---

## 🛠️ Forensic Analyst (Collecte / Commandes)

### Description
Exécute les commandes de collecte sur l’hôte compromis, crée les fichiers de preuve, calcule les empreintes numériques (hashes), et copie les artefacts vers le serveur evidence.

### Responsabilités
- Collecter processus, connexions, tâches planifiées, logs.  
- Sauvegarder chaque sortie dans un fichier horodaté.  
- Calculer les hashes SHA256 des fichiers suspects.  
- Copier les preuves sur `\\srv\evidence\inc_YYYYMMDD_HHMM\`.  
- Supprimer la persistance uniquement après validation du Chef.

### Livrables attendus
- `tasklist_hostXX_YYYYMMDD_HHMM.txt`  
- `netstat_hostXX_YYYYMMDD_HHMM.txt`  
- `schtasks_hostXX_YYYYMMDD_HHMM.txt`  
- `system_evtx_hostXX_YYYYMMDD_HHMM.evtx`  
- `hashes_inc_YYYYMMDD_HHMM.txt`  
- `evidence_inc_YYYYMMDD_HHMM.tar.gz` + `.sha256`

### Exemples
- Commandes Windows :  
```cmd
tasklist /FO LIST > C:\temp\tasklist_host21_20250920_0940.txt
netstat -ano > C:\temp\netstat_host21_20250920_0940.txt
schtasks /query /V /FO LIST > C:\temp\schtasks_host21_20250920_0940.txt
wevtutil epl System C:\temp\System_host21_20250920_0942.evtx
certutil -hashfile C:\Users\Public\staged.txt SHA256 > C:\temp\hashes_host21_20250920_0945.txt
robocopy C:\temp \\srv\evidence\inc_20250920_0930 /E /COPYALL /B /R:1 /W:1
````

* Journal (Forensic) :

  ```
  2025-09-20 09:38 | Claire (Forensic) | tasklist & netstat collectés ; copies vers \\srv\evidence\inc_20250920_0930\ ; hashes générés
  ```
* Validation avant suppression :

  ```
  2025-09-20 10:05 | Bob (Chef) | Autorisation suppression tâche UpdaterTask après collecte
  ```

---

## ✅ Résumé (tableau)

| Rôle     | Actions clés                                | Livrables                                                      | Exemple                                 |
| -------- | ------------------------------------------- | -------------------------------------------------------------- | --------------------------------------- |
| Chef     | Piloter, valider, journaliser, communiquer  | `journal_inc...`, `brief_direction...`, `message_users...`     | “Décision : isoler host-21”             |
| SOC      | Détecter, identifier IOC, orienter Forensic | `iocs_list...`, `explication_ioc...`                           | “IOC : IP 10.0.0.5 → netstat”           |
| Forensic | Collecter preuves, générer hashes, copier   | `tasklist...`, `netstat...`, `hashes_inc...`, archive evidence | `tasklist > C:\temp\tasklist_host21...` |

---

## ⛔ Règles communes

* Toute commande doit être validée par le Chef.
* Horodater toutes les actions.
* Ne jamais supprimer une preuve avant copie.
* Coopération obligatoire : SOC → Chef → Forensic.

