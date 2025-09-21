#!/bin/bash

# Azure Container Apps Deployment für LibreChat
# Dieses Skript deployt LibreChat auf Azure Container Apps

set -e

# Variablen - Bitte anpassen
RESOURCE_GROUP="librechat-rg"
ENVIRONMENT_NAME="librechat-env"
APP_NAME="librechat"
REGISTRY_NAME="librechatacr1758462248"
KEYVAULT_NAME="librechat-kv-1758461673"
STORAGE_ACCOUNT_NAME="librechat8354101"

echo "🚀 Azure Container Apps Deployment für LibreChat wird gestartet..."

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
az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.ContainerRegistry --wait
az provider register --namespace Microsoft.Storage --wait
az provider register --namespace Microsoft.KeyVault --wait
az provider register --namespace Microsoft.OperationalInsights --wait

# Variablen abfragen falls nicht gesetzt
if [ -z "$REGISTRY_NAME" ]; then
    read -p "Azure Container Registry Name: " REGISTRY_NAME
fi

if [ -z "$KEYVAULT_NAME" ]; then
    read -p "Azure Key Vault Name: " KEYVAULT_NAME
fi

if [ -z "$STORAGE_ACCOUNT_NAME" ]; then
    read -p "Azure Storage Account Name: " STORAGE_ACCOUNT_NAME
fi

# Registry URL abrufen
REGISTRY_URL=$(az acr show \
    --name $REGISTRY_NAME \
    --resource-group $RESOURCE_GROUP \
    --query loginServer \
    --output tsv)

# Container Apps Environment erstellen
echo "🌍 Container Apps Environment wird erstellt: $ENVIRONMENT_NAME"
az containerapp env create \
    --name $ENVIRONMENT_NAME \
    --resource-group $RESOURCE_GROUP \
    --location "Switzerland North"

# LibreChat API Container App erstellen
echo "📱 LibreChat API Container App wird erstellt..."
az containerapp create \
    --name "${APP_NAME}-api" \
    --resource-group $RESOURCE_GROUP \
    --environment $ENVIRONMENT_NAME \
    --image "librechatacr1758465933.azurecr.io/librechat-api:latest" \
    --target-port 3080 \
    --ingress external \
    --registry-server librechatacr1758465933.azurecr.io \
    --registry-username $(az acr credential show --name $REGISTRY_NAME --query username --output tsv) \
    --registry-password $(az acr credential show --name $REGISTRY_NAME --query passwords[0].value --output tsv) \
    --cpu 0.5 \
    --memory 1.0Gi \
    --min-replicas 1 \
    --max-replicas 3 \
    --env-vars \
        HOST=0.0.0.0 \
        NODE_ENV=production \
        PORT=3080 \
        MONGO_URI=mongodb://mongodb:27017/LibreChat \
        MEILI_HOST=http://meilisearch:7700 \
        RAG_PORT=8000 \
        RAG_API_URL=http://rag-api:8000 \
        MONGO_USERNAME=admin \
        MONGO_PASSWORD=QYY.ZxaPdUqB*Lyk-xs2aAPJ@oU6!PzfBe.Y \
        MEILI_MASTER_KEY=Xgc3L-iv7ZdkiNc.PGFWCHz8H6QLj@K.JrPF \
        POSTGRES_USERNAME=myuser \
        POSTGRES_PASSWORD=8TrCfqwtg@gZEusQJyt@K2VJ*jehP7LC9G-!

# LibreChat Client Container App erstellen
echo "🖥️ LibreChat Client Container App wird erstellt..."
az containerapp create \
    --name "${APP_NAME}-client" \
    --resource-group $RESOURCE_GROUP \
    --environment $ENVIRONMENT_NAME \
    --image "librechatacr1758465933.azurecr.io/nginx:1.27.0-alpine" \
    --target-port 80 \
    --ingress external \
    --registry-server librechatacr1758465933.azurecr.io \
    --registry-username $(az acr credential show --name $REGISTRY_NAME --query username --output tsv) \
    --registry-password $(az acr credential show --name $REGISTRY_NAME --query passwords[0].value --output tsv) \
    --cpu 0.25 \
    --memory 0.5Gi \
    --min-replicas 1 \
    --max-replicas 2

# MongoDB Container App erstellen
echo "🍃 MongoDB Container App wird erstellt..."
az containerapp create \
    --name "${APP_NAME}-mongodb" \
    --resource-group $RESOURCE_GROUP \
    --environment $ENVIRONMENT_NAME \
    --image "librechatacr1758465933.azurecr.io/mongo:latest" \
    --target-port 27017 \
    --ingress internal \
    --registry-server librechatacr1758465933.azurecr.io \
    --registry-username $(az acr credential show --name $REGISTRY_NAME --query username --output tsv) \
    --registry-password $(az acr credential show --name $REGISTRY_NAME --query passwords[0].value --output tsv) \
    --cpu 0.5 \
    --memory 1.0Gi \
    --min-replicas 1 \
    --max-replicas 1 \
    --env-vars \
        MONGO_INITDB_ROOT_USERNAME=admin \
        MONGO_INITDB_ROOT_PASSWORD=your-mongo-password

# Meilisearch Container App erstellen
echo "🔍 Meilisearch Container App wird erstellt..."
az containerapp create \
    --name "${APP_NAME}-meilisearch" \
    --resource-group $RESOURCE_GROUP \
    --environment $ENVIRONMENT_NAME \
    --image "librechatacr1758465933.azurecr.io/meilisearch:v1.12.3" \
    --target-port 7700 \
    --ingress internal \
    --registry-server librechatacr1758465933.azurecr.io \
    --registry-username $(az acr credential show --name $REGISTRY_NAME --query username --output tsv) \
    --registry-password $(az acr credential show --name $REGISTRY_NAME --query passwords[0].value --output tsv) \
    --cpu 0.25 \
    --memory 0.5Gi \
    --min-replicas 1 \
    --max-replicas 1 \
    --env-vars \
        MEILI_HOST=http://meilisearch:7700 \
        MEILI_NO_ANALYTICS=true \
        MEILI_MASTER_KEY=your-meili-master-key

# PostgreSQL Container App erstellen
echo "🐘 PostgreSQL Container App wird erstellt..."
az containerapp create \
    --name "${APP_NAME}-postgres" \
    --resource-group $RESOURCE_GROUP \
    --environment $ENVIRONMENT_NAME \
    --image "librechatacr1758465933.azurecr.io/pgvector:0.8.0-pg15-trixie" \
    --target-port 5432 \
    --ingress internal \
    --registry-server librechatacr1758465933.azurecr.io \
    --registry-username $(az acr credential show --name $REGISTRY_NAME --query username --output tsv) \
    --registry-password $(az acr credential show --name $REGISTRY_NAME --query passwords[0].value --output tsv) \
    --cpu 0.25 \
    --memory 0.5Gi \
    --min-replicas 1 \
    --max-replicas 1 \
    --env-vars \
        POSTGRES_DB=mydatabase \
        POSTGRES_USER=myuser \
        POSTGRES_PASSWORD=your-postgres-password

# RAG API Container App erstellen
echo "🤖 RAG API Container App wird erstellt..."
az containerapp create \
    --name "${APP_NAME}-rag-api" \
    --resource-group $RESOURCE_GROUP \
    --environment $ENVIRONMENT_NAME \
    --image "librechatacr1758465933.azurecr.io/librechat-rag-api:latest" \
    --target-port 8000 \
    --ingress internal \
    --registry-server librechatacr1758465933.azurecr.io \
    --registry-username $(az acr credential show --name $REGISTRY_NAME --query username --output tsv) \
    --registry-password $(az acr credential show --name $REGISTRY_NAME --query passwords[0].value --output tsv) \
    --cpu 0.5 \
    --memory 1.0Gi \
    --min-replicas 1 \
    --max-replicas 2 \
    --env-vars \
        DB_HOST=postgres \
        RAG_PORT=8000

# Container App URLs abrufen
API_URL=$(az containerapp show \
    --name "${APP_NAME}-api" \
    --resource-group $RESOURCE_GROUP \
    --query properties.configuration.ingress.fqdn \
    --output tsv)

CLIENT_URL=$(az containerapp show \
    --name "${APP_NAME}-client" \
    --resource-group $RESOURCE_GROUP \
    --query properties.configuration.ingress.fqdn \
    --output tsv)

echo "✅ Azure Container Apps Deployment abgeschlossen!"
echo ""
echo "📋 Wichtige Informationen:"
echo "Resource Group: $RESOURCE_GROUP"
echo "Environment: $ENVIRONMENT_NAME"
echo "API URL: https://${API_URL}"
echo "Client URL: https://${CLIENT_URL}"
echo ""
echo "🔧 Nächste Schritte:"
echo "1. Konfigurieren Sie Azure Files für persistente Speicherung"
echo "2. Testen Sie die Anwendung über die Client URL"
echo "3. Konfigurieren Sie SSL/TLS Zertifikate"
echo ""
echo "💡 Tipp: Verwenden Sie Azure Application Gateway für erweiterte Load Balancing Features!"
