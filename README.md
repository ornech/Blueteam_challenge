# 🔐 Blue Team Challenge — BTS SIO

Exercice pédagogique de cybersécurité orienté **Blue Team**.  
Objectif : plonger les étudiants en situation de **gestion d’incident** (attaque simulée, investigation, collecte de preuves, communication).

---

## 🎯 Objectifs pédagogiques
- Découvrir les étapes de la **réponse à incident** (Incident Response / IR).  
- Travailler en **équipe** avec des rôles distincts (Chef d’incident, SOC Analyste, Forensic Analyst).  
- Apprendre à **collecter, conserver et analyser des preuves** numériques.  
- Développer des réflexes de **communication en crise** (direction, utilisateurs).  
- Évaluer la capacité à **coopérer sous contrainte de temps**.

---

## 📂 Structure du dépôt

```

blue-team-challenge/
├── README.md                        # Présentation du projet
├── .gitignore                       # Fichiers à exclure
│
├── docs/                            # Documentation pédagogique
│   ├── introduction.md              # Contexte & déroulé du challenge
│   ├── playbook\_ir.md               # Playbook Incident Response (macro-processus)
│   ├── roles.md                     # Fiches de rôle (Chef, SOC, Forensic)
│   ├── cheatsheet\_cmds.md           # Commandes Windows/Linux/SIEM
│   ├── livrables.md                 # Liste des livrables attendus
│   └── regles\_securite.md           # Règles de sécurité du lab
│
├── scenarios/                       # Scénarios d’incidents
│   ├── scenario\_eleve\_phishing\_updatertask.md   # Version à donner aux étudiants
│   └── scenario\_teacher\_notes.md                # Notes pour l’enseignant (Red Team)
│
├── scripts/                         # Scripts de simulation & collecte
│   ├── linux\_collect.sh             # Collecte Linux (processus, logs, hashes)
│   ├── win\_collect.ps1              # Collecte Windows (tasklist, netstat, evtx)
│   └── red\_simulation.ps1           # Simulation Red Team (enseignant)
│
├── evaluation/                      # Évaluation et scoring
│   ├── grille\_evaluation.csv        # Barème par rôle
│   └── scoring\_correction\_template.csv # Modèle de correction
│
└── resources/                       # Ressources pédagogiques
├── journal\_template\_inc\_YYYYMMDD\_HHMM.txt   # Journal d’incident
├── brief\_direction\_template.txt            # Modèle de message direction
└── message\_users\_template.txt              # Modèle de message utilisateurs

````

---

## 🕹️ Déroulé du challenge

1. **Mise en situation** : l’enseignant (Red Team) injecte un incident simulé (phishing, tâche planifiée, exfiltration).  
2. **Réponse Blue Team** :  
   - SOC identifie les anomalies (logs, SIEM).  
   - Forensic collecte les preuves.  
   - Chef valide et tient la timeline + rédige communications.  
3. **Livrables obligatoires** (par rôle) sont produits et copiés dans `\\srv\evidence\inc_YYYYMMDD_HHMM`.  
4. **Débrief collectif** : chaque rôle présente ses résultats.  
5. **Évaluation** : basée sur la complétude des livrables, la coopération et la qualité de la communication.

---

## ⚖️ Règles essentielles
- Toute action doit être validée par le **Chef d’incident**.  
- Chaque rôle doit produire ses livrables (sinon perte de points).  
- **Ne jamais supprimer** une preuve avant copie.  
- Horodater chaque action : `YYYY-MM-DD HH:MM | Rôle | Action | Preuve`.  
- Travail strictement dans le **lab isolé** (aucune commande sur le réseau réel).  

---

## 🚀 Mise en place

1. Cloner le dépôt :  
   ```bash
   git clone https://github.com/<ton-compte>/blue-team-challenge.git
   cd blue-team-challenge
````

2. Distribuer les **fiches de rôle** (`docs/roles.md`) et la **cheat-sheet** (`docs/cheatsheet_cmds.md`) aux étudiants.
3. Lancer le scénario Red Team (`scripts/red_simulation.ps1`) dans la VM cible.
4. Suivre le déroulé avec le **playbook IR** et les livrables attendus.

---

## 📌 Licence

Ce projet est fourni sous licence **CC BY-SA** : libre utilisation et adaptation à condition de citer la source et de partager sous les mêmes conditions.

