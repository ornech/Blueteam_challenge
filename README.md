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

