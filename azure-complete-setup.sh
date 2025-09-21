#!/bin/bash

# Komplettes Azure Setup für LibreChat
# Dieses Skript führt alle Setup-Schritte automatisch aus

set -e

echo "🚀 Komplettes Azure Setup für LibreChat wird gestartet..."
echo ""

# Variablen
RESOURCE_GROUP="librechat-rg"
LOCATION="Switzerland North"

# Prüfen ob alle Skripte vorhanden sind
REQUIRED_SCRIPTS=(
    "azure-storage-setup.sh"
    "azure-keyvault-setup.sh"
    "azure-container-registry-setup.sh"
    "azure-deploy.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ ! -f "$script" ]; then
        echo "❌ Fehler: $script nicht gefunden!"
        exit 1
    fi
done

echo "✅ Alle erforderlichen Skripte gefunden"
echo ""

# Schritt 1: Azure Storage Setup
echo "📦 Schritt 1: Azure Storage wird eingerichtet..."
./azure-storage-setup.sh

echo ""
echo "⏸️  Bitte notieren Sie sich die Storage Account Informationen und drücken Sie Enter zum Fortfahren..."
read

# Schritt 2: Azure Key Vault Setup
echo "🔐 Schritt 2: Azure Key Vault wird eingerichtet..."
./azure-keyvault-setup.sh

echo ""
echo "⏸️  Bitte notieren Sie sich die Key Vault Informationen und drücken Sie Enter zum Fortfahren..."
read

# Schritt 3: Azure Container Registry Setup
echo "🐳 Schritt 3: Azure Container Registry wird eingerichtet..."
./azure-container-registry-setup.sh

echo ""
echo "⏸️  Bitte notieren Sie sich die Container Registry Informationen und drücken Sie Enter zum Fortfahren..."
read

# Schritt 4: Azure Container Apps Deployment
echo "🚀 Schritt 4: Azure Container Apps werden deployed..."
./azure-deploy.sh

echo ""
echo "🎉 Komplettes Azure Setup für LibreChat abgeschlossen!"
echo ""
echo "📋 Zusammenfassung:"
echo "✅ Azure Storage Account erstellt"
echo "✅ Azure Key Vault konfiguriert"
echo "✅ Azure Container Registry eingerichtet"
echo "✅ LibreChat auf Azure Container Apps deployed"
echo ""
echo "🔧 Nächste Schritte:"
echo "1. Testen Sie die Anwendung über die bereitgestellte URL"
echo "2. Konfigurieren Sie SSL/TLS Zertifikate"
echo "3. Richten Sie Monitoring und Logging ein"
echo "4. Konfigurieren Sie Backup-Strategien"
echo ""
echo "💡 Tipp: Verwenden Sie Azure Monitor für umfassendes Monitoring!"
