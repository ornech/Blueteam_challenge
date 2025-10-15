#!/usr/bin/env bash
# ------------------------------------------------------------
# check_wazuh_agent.sh
# Script de vérification complète de la configuration Wazuh Agent
# Référence : https://documentation.wazuh.com/current/agent/
# ------------------------------------------------------------
set -e

echo "🔎 Vérification de la configuration Wazuh Agent"
echo "------------------------------------------------------------"

# 1️⃣ Vérifier si le service wazuh-agent est installé
if ! systemctl list-unit-files | grep -q wazuh-agent; then
  echo "❌ wazuh-agent non installé"
  exit 1
fi
echo "✅ wazuh-agent installé"

# 2️⃣ Vérifier l’état du service
if systemctl is-active --quiet wazuh-agent; then
  echo "✅ Service actif"
else
  echo "⚠️ Service inactif"
  sudo systemctl status wazuh-agent --no-pager
fi

# Vérifier la version agent
echo -n "📦 Version : "
VERSION=$(sudo /var/ossec/bin/wazuh-agentd -V 2>&1 | tr -d '\r' | grep -m1 "Wazuh")
if [ -n "$VERSION" ]; then
  echo "$VERSION"
else
  echo "inconnue"
fi



# 4️⃣ Vérifier la configuration réseau de l’agent
echo "🌐 Interface réseau utilisée :"
ip addr show | grep "inet " | awk '{print $2}' | grep -v "127.0.0.1"

# 5️⃣ Vérifier la route par défaut
echo "🚦 Route par défaut :"
ip route | grep default || echo "⚠️ Aucune route par défaut configurée"

# 6️⃣ Vérifier la configuration du manager dans ossec.conf
CONF_FILE="/var/ossec/etc/ossec.conf"
if [ -f "$CONF_FILE" ]; then
  echo "📁 Configuration du manager dans $CONF_FILE :"
  MANAGER_IP=$(grep -m1 "<address>" "$CONF_FILE" | sed -E 's|.*<address>(.*)</address>.*|\1|')
  MANAGER_PORT=$(grep -m1 "<port>" "$CONF_FILE" | sed -E 's|.*<port>(.*)</port>.*|\1|')
  echo " IP  : $MANAGER_IP "
  echo " Port: $MANAGER_PORT"
  #grep -A2 "<server>" "$CONF_FILE" | grep -E "(<address>|<port>|<protocol>)" | sed 's/ //g'
else
  echo "❌ Fichier $CONF_FILE introuvable"
fi

# 7️⃣ Vérifier la clé d’enregistrement (agent.key)
if [ -f "/var/ossec/etc/client.keys" ]; then
  echo "🔑 Clé d'enregistrement présente"
  grep "$(hostname)" /var/ossec/etc/client.keys || echo "⚠️ Nom d’hôte non trouvé dans client.keys"
else
  echo "⚠️ client.keys manquant"
fi

# 8️⃣ Test de communication avec le manager
echo "📡 Test de connexion au manager..."
MANAGER_IP=$(grep -m1 "<address>" "$CONF_FILE" | sed -E 's|.*<address>(.*)</address>.*|\1|')
if ping -c 1 -W 2 "$MANAGER_IP" >/dev/null 2>&1; then
  echo "✅ Ping du manager réussi ($MANAGER_IP)"
else
  echo "⚠️ Impossible de joindre le manager ($MANAGER_IP)"
fi

# 9️⃣ Vérifier les logs récents de l’agent
echo "🧾 Derniers logs :"
sudo tail -n 10 /var/ossec/logs/ossec.log | sed 's/^/   /'

# 🔟 Vérifier la synchronisation avec le manager
echo "🔄 Vérification du statut d’enregistrement..."
sudo /var/ossec/bin/agent_control status || echo "⚠️ Impossible de récupérer le statut"

echo "------------------------------------------------------------"
echo "✅ Vérification terminée."

