#!/bin/bash

# Azure Container Registry Setup für LibreChat
# Dieses Skript richtet Azure Container Registry ein und pusht die Images

set -e

# Variablen - Bitte anpassen
RESOURCE_GROUP="librechat-rg"
REGISTRY_NAME="librechatacr$(date +%s)"
LOCATION="Switzerland North"

echo "🐳 Azure Container Registry Setup für LibreChat wird gestartet..."

# Prüfen ob Azure CLI installiert ist
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI ist nicht installiert. Bitte installieren Sie es zuerst."
    exit 1
fi

# Prüfen ob Docker installiert ist
if ! command -v docker &> /dev/null; then
    echo "❌ Docker ist nicht installiert. Bitte installieren Sie es zuerst."
    exit 1
fi

# Anmelden bei Azure (falls nicht bereits angemeldet)
echo "🔐 Anmeldung bei Azure..."
az login

# Resource Provider registrieren
echo "📋 Resource Provider werden registriert..."
az provider register --namespace Microsoft.ContainerRegistry --wait
az provider register --namespace Microsoft.Storage --wait
az provider register --namespace Microsoft.KeyVault --wait
az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.OperationalInsights --wait

# Container Registry erstellen
echo "📦 Azure Container Registry wird erstellt: $REGISTRY_NAME"
az acr create \
    --name $REGISTRY_NAME \
    --resource-group $RESOURCE_GROUP \
    --location "$LOCATION" \
    --sku Basic \
    --admin-enabled true

# Registry Login
echo "🔑 Anmeldung bei Container Registry..."
az acr login --name $REGISTRY_NAME

# Registry URL abrufen
REGISTRY_URL=$(az acr show \
    --name $REGISTRY_NAME \
    --resource-group $RESOURCE_GROUP \
    --query loginServer \
    --output tsv)

echo "📥 LibreChat Images werden zu Azure Container Registry gepusht..."

# LibreChat API Image (AMD64 für Azure)
echo "🔄 LibreChat API Image wird gepusht..."
docker pull --platform linux/amd64 ghcr.io/danny-avila/librechat-dev-api:latest
docker tag ghcr.io/danny-avila/librechat-dev-api:latest $REGISTRY_URL/librechat-api:latest
docker push $REGISTRY_URL/librechat-api:latest

# LibreChat RAG API Image (AMD64 für Azure)
echo "🔄 LibreChat RAG API Image wird gepusht..."
docker pull --platform linux/amd64 ghcr.io/danny-avila/librechat-rag-api-dev-lite:latest
docker tag ghcr.io/danny-avila/librechat-rag-api-dev-lite:latest $REGISTRY_URL/librechat-rag-api:latest
docker push $REGISTRY_URL/librechat-rag-api:latest

# Nginx Image (AMD64 für Azure)
echo "🔄 Nginx Image wird gepusht..."
docker pull --platform linux/amd64 nginx:1.27.0-alpine
docker tag nginx:1.27.0-alpine $REGISTRY_URL/nginx:1.27.0-alpine
docker push $REGISTRY_URL/nginx:1.27.0-alpine

# MongoDB Image (AMD64 für Azure)
echo "🔄 MongoDB Image wird gepusht..."
docker pull --platform linux/amd64 mongo:latest
docker tag mongo:latest $REGISTRY_URL/mongo:latest
docker push $REGISTRY_URL/mongo:latest

# Meilisearch Image (AMD64 für Azure)
echo "🔄 Meilisearch Image wird gepusht..."
docker pull --platform linux/amd64 getmeili/meilisearch:v1.12.3
docker tag getmeili/meilisearch:v1.12.3 $REGISTRY_URL/meilisearch:v1.12.3
docker push $REGISTRY_URL/meilisearch:v1.12.3

# PostgreSQL Image (AMD64 für Azure)
echo "🔄 PostgreSQL Image wird gepusht..."
docker pull --platform linux/amd64 pgvector/pgvector:0.8.0-pg15-trixie
docker tag pgvector/pgvector:0.8.0-pg15-trixie $REGISTRY_URL/pgvector:0.8.0-pg15-trixie
docker push $REGISTRY_URL/pgvector:0.8.0-pg15-trixie

# Registry Credentials abrufen
REGISTRY_USERNAME=$(az acr credential show \
    --name $REGISTRY_NAME \
    --query username \
    --output tsv)

REGISTRY_PASSWORD=$(az acr credential show \
    --name $REGISTRY_NAME \
    --query passwords[0].value \
    --output tsv)

echo "✅ Azure Container Registry Setup abgeschlossen!"
echo ""
echo "📋 Wichtige Informationen:"
echo "Registry Name: $REGISTRY_NAME"
echo "Registry URL: $REGISTRY_URL"
echo "Username: $REGISTRY_USERNAME"
echo "Password: $REGISTRY_PASSWORD"
echo "Resource Group: $RESOURCE_GROUP"
echo ""
echo "🔧 Nächste Schritte:"
echo "1. Aktualisieren Sie die azure-container-apps.yaml mit der Registry URL"
echo "2. Deployen Sie die Container Apps"
echo ""
echo "💡 Tipp: Speichern Sie die Registry-Credentials sicher für Container Apps!"
