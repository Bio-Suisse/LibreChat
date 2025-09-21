#!/bin/bash

# Azure Storage Setup für LibreChat
# Dieses Skript richtet Azure Storage für persistente Daten ein

set -e

# Variablen - Bitte anpassen
RESOURCE_GROUP="librechat-rg"
LOCATION="Switzerland North"
# Storage Account Name muss 3-24 Zeichen, nur Kleinbuchstaben und Zahlen
STORAGE_ACCOUNT_NAME="librechat$(date +%s | tail -c 8)"
SHARE_NAME_PREFIX="librechat"

echo "🚀 Azure Storage Setup für LibreChat wird gestartet..."

# Prüfen ob Azure CLI installiert ist
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI ist nicht installiert. Bitte installieren Sie es zuerst."
    exit 1
fi

# Anmelden bei Azure (falls nicht bereits angemeldet)
echo "🔐 Anmeldung bei Azure..."
az login

# Resource Provider registrieren
echo "📋 Resource Provider werden registriert..."
az provider register --namespace Microsoft.Storage --wait
az provider register --namespace Microsoft.KeyVault --wait
az provider register --namespace Microsoft.ContainerRegistry --wait
az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.OperationalInsights --wait

# Resource Group erstellen (falls bereits vorhanden, wird sie gelöscht und neu erstellt)
echo "📦 Resource Group wird erstellt: $RESOURCE_GROUP"
if az group show --name $RESOURCE_GROUP &> /dev/null; then
    echo "⚠️  Resource Group existiert bereits. Wird gelöscht und neu erstellt..."
    az group delete --name $RESOURCE_GROUP --yes --no-wait
    echo "⏳ Warten auf Löschung der Resource Group..."
    sleep 30
fi

az group create \
    --name $RESOURCE_GROUP \
    --location "$LOCATION"

# Storage Account erstellen
echo "💾 Storage Account wird erstellt: $STORAGE_ACCOUNT_NAME"
az storage account create \
    --name $STORAGE_ACCOUNT_NAME \
    --resource-group $RESOURCE_GROUP \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2

# Storage Account Key abrufen
echo "🔑 Storage Account Key wird abgerufen..."
STORAGE_KEY=$(az storage account keys list \
    --resource-group $RESOURCE_GROUP \
    --account-name $STORAGE_ACCOUNT_NAME \
    --query '[0].value' \
    --output tsv)

# File Shares erstellen
echo "📁 File Shares werden erstellt..."

# MongoDB Daten
az storage share create \
    --name "${SHARE_NAME_PREFIX}-mongodb" \
    --account-name $STORAGE_ACCOUNT_NAME \
    --account-key $STORAGE_KEY

# Meilisearch Daten
az storage share create \
    --name "${SHARE_NAME_PREFIX}-meilisearch" \
    --account-name $STORAGE_ACCOUNT_NAME \
    --account-key $STORAGE_KEY

# PostgreSQL Daten
az storage share create \
    --name "${SHARE_NAME_PREFIX}-postgres" \
    --account-name $STORAGE_ACCOUNT_NAME \
    --account-key $STORAGE_KEY

# LibreChat Images
az storage share create \
    --name "${SHARE_NAME_PREFIX}-images" \
    --account-name $STORAGE_ACCOUNT_NAME \
    --account-key $STORAGE_KEY

# LibreChat Uploads
az storage share create \
    --name "${SHARE_NAME_PREFIX}-uploads" \
    --account-name $STORAGE_ACCOUNT_NAME \
    --account-key $STORAGE_KEY

# LibreChat Logs
az storage share create \
    --name "${SHARE_NAME_PREFIX}-logs" \
    --account-name $STORAGE_ACCOUNT_NAME \
    --account-key $STORAGE_KEY

# Storage Account Connection String
CONNECTION_STRING=$(az storage account show-connection-string \
    --name $STORAGE_ACCOUNT_NAME \
    --resource-group $RESOURCE_GROUP \
    --query connectionString \
    --output tsv)

echo "✅ Azure Storage Setup abgeschlossen!"
echo ""
echo "📋 Wichtige Informationen:"
echo "Resource Group: $RESOURCE_GROUP"
echo "Storage Account: $STORAGE_ACCOUNT_NAME"
echo "Connection String: $CONNECTION_STRING"
echo ""
echo "🔧 Nächste Schritte:"
echo "1. Speichern Sie diese Informationen sicher"
echo "2. Konfigurieren Sie Azure Key Vault für Secrets"
echo "3. Deployen Sie die Container Apps mit dem Deployment-Skript"
echo ""
echo "💡 Tipp: Verwenden Sie Azure Key Vault für sichere Speicherung der Secrets!"
