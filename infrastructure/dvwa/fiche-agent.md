# Agent Wazuh – Fiche de configuration

## Table des matières
- [L’agent Wazuh](#lagent-wazuh)
  - [Rôle général](#rôle-général)
  - [Architecture et communication](#architecture-et-communication)
  - [Principales fonctionnalités](#principales-fonctionnalités)
- [Installation d’un agent](#installation-dun-agent)
- [Tests de configuration](#tests-de-configuration)
  - [Vérifiez la configuration](#vérifiez-la-configuration)
  - [Vérifiez les clés d’authentification](#vérifiez-les-clés-dauthentification)
  - [Vérifiez la connectivité](#vérifiez-la-connectivité)
  - [Vérifiez que l’agent soit lancé](#vérifiez-que-lagent-soit-lancé)
  - [Vérifiez la remontée d’information](#vérifiez-la-remontée-dinformation)
- [Ajustement des buffers](#ajustement-des-buffers)
- [Schéma d’architecture Wazuh](#schéma-darchitecture-wazuh)

---

## L’agent Wazuh

### Rôle général
L’agent Wazuh est le composant installé sur chaque machine (serveur, poste client, conteneur, VM, etc.) que l’on souhaite surveiller.  
Il collecte, analyse et transmet les événements de sécurité au **Wazuh Manager** via une communication sécurisée.

> 🧩 Il agit comme une sonde de sécurité locale.  
> 📡 Il remonte les journaux, inventaires, alertes et indicateurs d’intégrité.

---

### Architecture et communication

| Élément | Fonction |
|----------|-----------|
| **Agent** | Collecte les logs, surveille les fichiers, exécute des modules de sécurité. |
| **Manager** | Centralise, corrèle et alerte selon les règles. |
| **Canal de communication** | TCP/1514 (logs), TCP/1515 (authentification), chiffré via AES ou TLS. |
| **Processus principaux** | `wazuh-agentd`, `wazuh-logcollector`, `wazuh-syscheckd`, `wazuh-modulesd`. |

💡 L’agent utilise une clé unique (stockée dans `/var/ossec/etc/client.keys`) pour s’authentifier auprès du manager.

---

### Principales fonctionnalités

| Fonction | Description | Module / Service |
|-----------|--------------|------------------|
| **Collecte de logs** | Surveille des fichiers (syslog, auth.log, apache2/access.log, etc.) et envoie les entrées au manager. | `wazuh-logcollector` |
| **Surveillance d’intégrité (FIM)** | Compare les signatures des fichiers critiques pour détecter les modifications non autorisées. | `wazuh-syscheckd` |
| **Détection de rootkits** | Vérifie la présence de processus ou fichiers suspects, ports ouverts anormaux, etc. | `rootcheck` |
| **Inventaire du système** | Recense le matériel, paquets installés, interfaces, ports, processus, etc. | `syscollector` |
| **Évaluation de configuration (SCA)** | Analyse la conformité du système selon des politiques (CIS, ISO, etc.). | `sca` |
| **Collecte via commandes personnalisées** | Exécute périodiquement des commandes locales (`df -P`, `netstat`, etc.). | `localfile` (format command) |

---

## Installation d’un agent

Wazuh permet de déployer un agent directement depuis le **Dashboard** :

1. Connectez-vous au Dashboard Wazuh (`admin/admin` par défaut).  
2. Accédez au menu : **Agents management → Summary**.  
3. Cliquez sur **Deploy new agent**.  
4. Sélectionnez :
   - Le système d’exploitation (Linux, Windows, macOS)
   - La version d’agent compatible
   - Le mode d’installation (paquet, script, agent Docker)
5. Copiez la commande proposée et exécutez-la sur la machine cible.

📚 Documentation officielle :  
[https://documentation.wazuh.com/current/installation-guide/wazuh-agent/index.html](https://documentation.wazuh.com/current/installation-guide/wazuh-agent/index.html)

---

## Tests de configuration

### Vérifiez la configuration

Fichier principal : `/var/ossec/etc/ossec.conf`

```xml
<ossec_config>
  <client>
    <server>
      <address>192.168.56.7</address> <!-- IP du manager Wazuh -->
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
  </client>

  <!-- Exemple de collecte Apache -->
  <localfile>
    <log_format>apache</log_format>
    <location>/var/log/apache2/access.log</location>
  </localfile>

  <syscheck> ... </syscheck>
  <sca> ... </sca>
  <rootcheck> ... </rootcheck>
</ossec_config>
````

💡 Chaque section `<localfile>` déclare un fichier de log à surveiller.

```bash
sudo cat /var/ossec/etc/ossec.conf | grep /var/log/apache2
```

Si la ligne suivante n’apparaît pas :

```bash
<location>/var/log/apache2/access.log</location>
```

Ajoutez-la :

```xml
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/apache2/access.log</location>
</localfile>
```

Redémarrez ensuite l’agent :

```bash
sudo systemctl restart wazuh-agent
```

Et vérifiez :

```bash
sudo systemctl status wazuh-agent
sudo cat /var/ossec/logs/ossec.log | grep Analyzing
```

---

### Vérifiez les clés d’authentification

Les clés doivent être identiques sur le **manager** et l’**agent**.

**Sur le manager :**

```bash
sudo cat /var/ossec/etc/client.keys
001 Linux-test any 01bcc721414b505d6a8cebc0b8eb7576ed95487aff6bd73c4b6876df7cbdbaa7
002 agent-dvwa any 20d007e7374644184980e9c79edf264fde9f553cf9040c730c249947e9e52f7a
```

**Sur l’agent :**

```bash
sudo cat /var/ossec/etc/client.keys
002 agent-dvwa any 20d007e7374644184980e9c79edf264fde9f553cf9040c730c249947e9e52f7a
```

---

### Vérifiez la connectivité

```bash
nc -vz 192.168.56.7 1514
```

Résultat attendu :

```
Connection to 192.168.56.7 1514 port [tcp/*] succeeded!
```

---

### Vérifiez que l’agent soit lancé

```bash
sudo systemctl status wazuh-agent
```

Résultat attendu :

```
Active: active (running)
Processus visibles :
- wazuh-execd
- wazuh-agentd
- wazuh-syscheckd
- wazuh-logcollector
- wazuh-modulesd
```

---

### Vérifiez la remontée d’information

Depuis le **manager** :

```bash
sudo /var/ossec/bin/agent_control -lc
```

Résultat attendu :

```
Wazuh agent_control. List of available agents:
 ID: 000, Name: wazuh-server (server), IP: 127.0.0.1, Active/Local
 ID: 002, Name: agent-dvwa, IP: any, Active   ← ICI
```

---

## Ajustement des buffers

Fichier : `/var/ossec/etc/local_internal_options.conf`

```ini
# -- Augmenter la file de collecte --
logcollector.remote_queue_size=8192
logcollector.queue_size=20480
# -- File interne agentd --
agent.buffer_size=16384
agent.remote_timeout=20
agent.control_keep_alive=30
```

---

## Schéma d’architecture Wazuh

```
       ┌────────────────────┐
       │   Wazuh Dashboard  │
       └───────┬────────────┘
               │
         ┌─────┴─────┐
         │ Wazuh API  │
         └─────┬─────┘
               │
     ┌─────────┴──────────┐
     │ Wazuh Manager (srv)│
     └─────────┬──────────┘
               │  TCP/1514–1515
      ┌────────┴────────┐
      │     Agent(s)    │
      │ (Linux, Win, VM)│
      └─────────────────┘
```

---

🧭 **Référence officielle :**
[Wazuh Documentation – Agent](https://documentation.wazuh.com/current/user-manual/agents/index.html)

```
