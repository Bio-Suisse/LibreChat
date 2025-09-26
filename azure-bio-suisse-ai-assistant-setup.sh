#!/bin/bash

# Azure Bio Suisse AI Assistant Setup
# Dieses Skript richtet den Azure Bio Suisse AI Assistant ein

# Die Azure CLI muss vorhanden sein


# Variablen
RESOURCE_GROUP="bio-suisse-ai-assistant-rg"
ENVIRONMENT_NAME="bio-suisse-ai-assistant-env"
APP_NAME="bio-suisse-ai-assistant"
AZURE_LOCATION="Switzerland North"
STORAGE_ACCOUNT_NAME="bio-suisse-ai-assistant-storage"
KEYVAULT_NAME="bio-suisse-ai-assistant-kv"
MONGO_APP_NAME="bio-suisse-ai-assistant-mongodb"
MEILISEARCH_APP_NAME="bio-suisse-ai-assistant-meilisearch"
POSTGRES_APP_NAME="bio-suisse-ai-assistant-postgres"
RAG_API_APP_NAME="bio-suisse-ai-assistant-rag-api"
LIBRECHAT_API_APP_NAME="bio-suisse-ai-assistant-librechat-api"


# ------------------------------------------------------------
# ------------------------------------------------------------
# SETUP STEPS
# ------------------------------------------------------------
# ------------------------------------------------------------

# ------------------------------------------------------------
# STEP 1: Create Azure Resource Group
# ------------------------------------------------------------
az group create --name $RESOURCE_GROUP --location $AZURE_LOCATION

# ------------------------------------------------------------
# STEP 2: Create Azure Container Registry
# ------------------------------------------------------------
az acr create --name $RESOURCE_GROUP --resource-group $RESOURCE_GROUP --sku Basic --admin-enabled true

# ------------------------------------------------------------
# STEP 3: Create Azure Container App Environment
# ------------------------------------------------------------
az containerapp env create --name $ENVIRONMENT_NAME --resource-group $RESOURCE_GROUP --location $AZURE_LOCATION

# ------------------------------------------------------------
# STEP 4: Create Azure Storage Account
# ------------------------------------------------------------
az storage account create --name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP --location $AZURE_LOCATION --sku Standard_LRS --kind StorageV2

# ------------------------------------------------------------
# STEP 5: Create Azure Key Vault
# ------------------------------------------------------------
az keyvault create --name $KEYVAULT_NAME --resource-group $RESOURCE_GROUP --location $AZURE_LOCATION



# ------------------------------------------------------------
# ------------------------------------------------------------
# CONTTAINER APPS DEPLOYMENT
# ------------------------------------------------------------
# ------------------------------------------------------------


# ------------------------------------------------------------
# STEP 6: Create MongoDB Container App (OPEN POINTS)
# ------------------------------------------------------------
az containerapp create \
    --name $MONGO_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --environment $ENVIRONMENT_NAME \
    --image mongo:latest \
    --target-port 27017 \
    --ingress internal \
    --env-vars MONGO_INITDB_ROOT_USERNAME=admin MONGO_INITDB_ROOT_PASSWORD=your-password

# ------------------------------------------------------------
# STEP 7: Create Meilisearch Container App
# ------------------------------------------------------------
az containerapp create \
    --name $MEILISEARCH_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --environment $ENVIRONMENT_NAME \
    --image getmeili/meilisearch:v1.12.3 \
    --target-port 7700 \
    --ingress internal \
    --env-vars \
        MEILI_NO_ANALYTICS=true \
        MEILI_MASTER_KEY=your-master-key

# ------------------------------------------------------------
# STEP 8: Create Postgres Container App 
# ------------------------------------------------------------
az containerapp create \
    --name $POSTGRES_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --environment $ENVIRONMENT_NAME \
    --image pgvector/pgvector:0.8.0-pg15-trixie \
    --target-port 5432 \
    --ingress internal \
    --env-vars \
        POSTGRES_DB=mydatabase \
        POSTGRES_USER=myuser \
        POSTGRES_PASSWORD=your-password

# ------------------------------------------------------------
# STEP 9: Create RAG API Container App
# ------------------------------------------------------------
az containerapp create \
    --name $RAG_API_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --environment $ENVIRONMENT_NAME \
    --image ghcr.io/danny-avila/librechat-rag-api-dev-lite:latest \
    --target-port 8000 \
    --ingress internal \
    --env-vars \
        DB_HOST=vectordb \
        RAG_PORT=8000

# ------------------------------------------------------------
# STEP 10: Create LibreChat API Container App (MAIN APP)
# ------------------------------------------------------------
az containerapp create \
    --name $LIBRECHAT_API_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --environment $ENVIRONMENT_NAME \
    --image ghcr.io/danny-avila/librechat-dev:latest \
    --target-port 3080 \
    --ingress internal \
    --env-vars \
        HOST=0.0.0.0 \
        PORT=3080 \
        MONGO_URI=mongodb://mongodb:27017/LibreChat \
        MEILI_HOST=http://meilisearch:7700 \
        RAG_PORT=8000 \
        RAG_API_URL=http://rag-api:8000