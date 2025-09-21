#!/bin/bash

# Azure Container Registry Image Push für LibreChat
# Dieses Skript pusht alle Images zur neuen Registry

set -e

# Variablen
REGISTRY_NAME="librechatacr1758465933"
REGISTRY_URL="librechatacr1758465933.azurecr.io"

echo "🐳 Azure Container Registry Image Push für LibreChat wird gestartet..."

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

# Registry Login
echo "🔑 Anmeldung bei Container Registry..."
az acr login --name $REGISTRY_NAME

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

echo "✅ Azure Container Registry Image Push abgeschlossen!"
echo ""
echo "📋 Wichtige Informationen:"
echo "Registry Name: $REGISTRY_NAME"
echo "Registry URL: $REGISTRY_URL"
echo ""
echo "🔧 Nächste Schritte:"
echo "1. Deployen Sie die Container Apps mit dem Deployment-Skript"
echo "2. Testen Sie die Anwendung"
echo ""
echo "💡 Tipp: Alle Images sind jetzt für Linux/AMD64 kompatibel!"
