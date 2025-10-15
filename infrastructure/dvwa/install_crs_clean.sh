#!/usr/bin/env bash
# ------------------------------------------------------------
# install_crs_clean.sh
# Installation propre du Core Rule Set (OWASP CRS)
# pour Apache + ModSecurity sur Debian/Ubuntu
# ------------------------------------------------------------
set -e

echo "🧹 Nettoyage des anciennes installations..."
sudo systemctl stop apache2 || true
sudo rm -rf /usr/share/modsecurity-crs /usr/share/owasp-crs
sudo rm -f /etc/apache2/conf-available/owasp-crs.conf /etc/apache2/conf-enabled/owasp-crs.conf
sudo rm -f /etc/apache2/mods-available/security2.conf /etc/apache2/mods-enabled/security2.conf

echo "📦 Installation de ModSecurity..."
sudo apt update -y
sudo apt install -y libapache2-mod-security2 git

echo "✅ Activation du module security2..."
sudo a2enmod security2

echo "⬇️ Téléchargement du Core Rule Set officiel..."
cd /usr/share
sudo git clone https://github.com/coreruleset/coreruleset.git
sudo mv coreruleset modsecurity-crs
sudo cp /usr/share/modsecurity-crs/crs-setup.conf.example /usr/share/modsecurity-crs/crs-setup.conf

echo "⚙️ Configuration du module security2.conf..."
cat <<'EOF' | sudo tee /etc/apache2/mods-available/security2.conf >/dev/null
<IfModule security2_module>
    # Fichier principal de ModSecurity
    Include /etc/modsecurity/modsecurity.conf

    # Activation du Core Rule Set (OWASP CRS)
    Include /usr/share/modsecurity-crs/crs-setup.conf
    Include /usr/share/modsecurity-crs/rules/*.conf
</IfModule>
EOF

echo "🔧 Configuration de /etc/modsecurity/modsecurity.conf..."
sudo sed -i 's/^SecRuleEngine .*/SecRuleEngine DetectionOnly/' /etc/modsecurity/modsecurity.conf
sudo sed -i 's/^SecAuditEngine .*/SecAuditEngine On/' /etc/modsecurity/modsecurity.conf
sudo sed -i 's|^SecAuditLog .*|SecAuditLog /var/log/apache2/modsec_audit.log|' /etc/modsecurity/modsecurity.conf
sudo sed -i 's|^#\?SecAuditLogRelevantStatus .*|# SecAuditLogRelevantStatus "^(?:5|4(?!04))"|' /etc/modsecurity/modsecurity.conf
sudo sed -i 's|^SecAuditLogType .*|SecAuditLogType Serial|' /etc/modsecurity/modsecurity.conf
sudo sed -i 's|^SecAuditLogStorageDir .*|# SecAuditLogStorageDir /var/log/apache2/audit/|' /etc/modsecurity/modsecurity.conf
sudo sed -i 's|^#\?SecAuditLogFormat .*|SecAuditLogFormat JSON|' /etc/modsecurity/modsecurity.conf

echo "📁 Préparation des dossiers de logs..."
sudo mkdir -p /var/log/apache2/audit
sudo touch /var/log/apache2/modsec_audit.log
sudo chown -R www-data:adm /var/log/apache2
# sudo chmod 750 /var/log/apache2/audit

echo "🔁 Redémarrage d'Apache..."
sudo systemctl restart apache2

echo "🧪 Vérification du service..."
if sudo systemctl is-active --quiet apache2; then
    echo "✅ Apache fonctionne."
else
    echo "❌ Erreur lors du redémarrage d'Apache. Consultez :"
    echo "   sudo journalctl -xeu apache2 | grep -i modsecurity"
    exit 1
fi

echo "📄 Test du CRS (XSS)..."
curl -s "http://localhost/?id=<script>alert(1)</script>" >/dev/null || true
sleep 2

if sudo grep -q 'id "941100"' /var/log/apache2/modsec_audit.log || \
   sudo grep -R "941100" /var/log/apache2/audit/ >/dev/null 2>&1; then
    echo "✅ CRS opérationnel : attaque XSS détectée (règle 941100)."
else
    echo "⚠️ CRS installé mais aucune alerte détectée. Vérifiez les logs."
    echo "   sudo tail -F /var/log/apache2/modsec_audit.log"
fi

echo "🚀 Installation terminée."

