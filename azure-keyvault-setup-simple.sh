#!/bin/bash

# Azure Key Vault Setup für LibreChat (Einfache Version ohne RBAC)
# Dieses Skript richtet Azure Key Vault für sichere Secrets-Verwaltung ein

set -e

# Variablen - Bitte anpassen
RESOURCE_GROUP="librechat-rg"
KEYVAULT_NAME="librechat-kv-$(date +%s)"
LOCATION="Switzerland North"

echo "🔐 Azure Key Vault Setup für LibreChat wird gestartet..."

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
az provider register --namespace Microsoft.KeyVault --wait
az provider register --namespace Microsoft.Storage --wait
az provider register --namespace Microsoft.ContainerRegistry --wait
az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.OperationalInsights --wait

# Key Vault erstellen (ohne RBAC für einfachere Berechtigung)
echo "🏦 Key Vault wird erstellt: $KEYVAULT_NAME"
az keyvault create \
    --name $KEYVAULT_NAME \
    --resource-group $RESOURCE_GROUP \
    --location "$LOCATION" \
    --enable-rbac-authorization false

# Aktuellen Benutzer als Key Vault Administrator hinzufügen (Access Policy)
echo "👤 Berechtigungen werden konfiguriert..."
CURRENT_USER_ID=$(az ad signed-in-user show --query id --output tsv)
az keyvault set-policy \
    --name $KEYVAULT_NAME \
    --resource-group $RESOURCE_GROUP \
    --object-id $CURRENT_USER_ID \
    --secret-permissions get list set delete recover backup restore purge

# Secrets hinzufügen
echo "🔑 Secrets werden zu Key Vault hinzugefügt..."

# MongoDB Secrets
echo "📝 MongoDB Secrets werden hinzugefügt..."
read -p "MongoDB Username (Standard: admin): " MONGO_USERNAME
MONGO_USERNAME=${MONGO_USERNAME:-admin}

read -s -p "MongoDB Password: " MONGO_PASSWORD
echo ""

az keyvault secret set \
    --vault-name $KEYVAULT_NAME \
    --name "mongo-username" \
    --value "$MONGO_USERNAME"

az keyvault secret set \
    --vault-name $KEYVAULT_NAME \
    --name "mongo-password" \
    --value "$MONGO_PASSWORD"

# Meilisearch Master Key
echo "🔍 Meilisearch Master Key wird hinzugefügt..."
read -s -p "Meilisearch Master Key: " MEILI_MASTER_KEY
echo ""

az keyvault secret set \
    --vault-name $KEYVAULT_NAME \
    --name "meili-master-key" \
    --value "$MEILI_MASTER_KEY"

# PostgreSQL Secrets
echo "🐘 PostgreSQL Secrets werden hinzugefügt..."
read -p "PostgreSQL Username (Standard: myuser): " POSTGRES_USERNAME
POSTGRES_USERNAME=${POSTGRES_USERNAME:-myuser}

read -s -p "PostgreSQL Password: " POSTGRES_PASSWORD
echo ""

az keyvault secret set \
    --vault-name $KEYVAULT_NAME \
    --name "postgres-username" \
    --value "$POSTGRES_USERNAME"

az keyvault secret set \
    --vault-name $KEYVAULT_NAME \
    --name "postgres-password" \
    --value "$POSTGRES_PASSWORD"

# API Keys (optional)
echo "🤖 API Keys (optional) - Drücken Sie Enter zum Überspringen:"
read -p "OpenAI API Key: " OPENAI_API_KEY
if [ ! -z "$OPENAI_API_KEY" ]; then
    az keyvault secret set \
        --vault-name $KEYVAULT_NAME \
        --name "openai-api-key" \
        --value "$OPENAI_API_KEY"
fi

read -p "Groq API Key: " GROQ_API_KEY
if [ ! -z "$GROQ_API_KEY" ]; then
    az keyvault secret set \
        --vault-name $KEYVAULT_NAME \
        --name "groq-api-key" \
        --value "$GROQ_API_KEY"
fi

# Key Vault URL abrufen
KEYVAULT_URL=$(az keyvault show \
    --name $KEYVAULT_NAME \
    --resource-group $RESOURCE_GROUP \
    --query properties.vaultUri \
    --output tsv)

echo "✅ Azure Key Vault Setup abgeschlossen!"
echo ""
echo "📋 Wichtige Informationen:"
echo "Key Vault Name: $KEYVAULT_NAME"
echo "Key Vault URL: $KEYVAULT_URL"
echo "Resource Group: $RESOURCE_GROUP"
echo ""
echo "🔧 Nächste Schritte:"
echo "1. Konfigurieren Sie Azure Container Registry"
echo "2. Deployen Sie die Container Apps mit Key Vault Integration"
echo ""
echo "💡 Tipp: Verwenden Sie Azure Container Apps mit Key Vault Integration für sichere Secrets!"
