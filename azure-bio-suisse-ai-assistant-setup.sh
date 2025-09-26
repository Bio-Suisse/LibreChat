#!/bin/bash

# Azure Bio Suisse AI Assistant Setup
# Dieses Skript richtet den Azure Umgebung für den Bio Suisse AI Assistant ein
# Es baut ausserdem die Container Images für die einzelnen Services und push sie an den Azure Container Registry
# Die Azure CLI muss vorhanden sein
# Docker muss vorhanden sein


# Skript stops if error occurs
set -e          # stops if error occurs
set -u          # stops if undefined variables are used
set -o pipefail # stops if errors occur in pipelines

# ------------------------------------------------------------
# VARIABLES
# ------------------------------------------------------------
RESOURCE_GROUP="bio-ai-assist-rg"
ENVIRONMENT_NAME="bio-ai-assist-env"
APP_NAME="bio-ai-assistant"
AZURE_LOCATION="switzerlandnorth"
STORAGE_ACCOUNT_NAME="bioaiassist"
KEYVAULT_NAME="bioaiassistkv"
MONGO_APP_NAME="bio-ai-mongodb"
MEILISEARCH_APP_NAME="bio-ai-meilisearch"
POSTGRES_APP_NAME="bio-ai-postgres"
RAG_API_APP_NAME="bio-ai-rag-api"
LIBRECHAT_API_APP_NAME="bio-ai-librechat-api"
ACR_NAME="bioaiassistacr"
LOG_ANALYTICS_WORKSPACE="bio-ai-assistant-logs"


# Prüfe ob --help Parameter übergeben wurde
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Azure Bio Suisse AI Assistant Setup Script"
    echo ""
    echo "Usage:"
    echo "  $0              # Setup Azure resources"
    echo "  $0 --build     # Build and push container images"
    echo "  $0 --revert     # Delete all Azure resources"
    echo "  $0 --help       # Show this help"
    echo ""
    echo "This script creates the following Azure resources:"
    echo "  - Resource Group: $RESOURCE_GROUP"
    echo "  - Container Registry: $ACR_NAME"
    echo "  - Container App Environment: $ENVIRONMENT_NAME"
    echo "  - Storage Account: $STORAGE_ACCOUNT_NAME"
    echo "  - Key Vault: $KEYVAULT_NAME"
    echo "  - Container Apps: MongoDB, Meilisearch, Postgres, RAG API, LibreChat API"
    echo ""
    echo "Container Images:"
    echo "  - LibreChat API: Custom build from current directory"
    echo "  - RAG API: Custom build from packages/api directory"
    echo "  - MongoDB, Meilisearch, Postgres: Public images"
    exit 0
fi


# ------------------------------------------------------------
# ------------------------------------------------------------
# AZURE BUILD STEPS
# ------------------------------------------------------------
# ------------------------------------------------------------

# Prüfe ob --build Parameter übergeben wurde
if [[ "${1:-}" == "--build" ]]; then
    echo "🔨 Building and pushing container images..."
    
    # Login to Azure Container Registry
    echo "🔐 Logging into Azure Container Registry: $ACR_NAME"
    az acr login --name $ACR_NAME
    
    # Get ACR login server
    ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query loginServer -o tsv)
    
    # Build and push LibreChat API
    echo "📱 Building LibreChat API image..."
    docker build -t $ACR_LOGIN_SERVER/librechat:latest .
    docker push $ACR_LOGIN_SERVER/librechat:latest
    
    # Build and push RAG API (if packages/api exists)
    if [[ -d "packages/api" ]]; then
        echo "🤖 Building RAG API image..."
        docker build -t $ACR_LOGIN_SERVER/rag-api:latest ./packages/api
        docker push $ACR_LOGIN_SERVER/rag-api:latest
    else
        echo "⚠️  packages/api directory not found, skipping RAG API build"
    fi
    
    echo "✅ Container images built and pushed successfully!"
    echo "💡 You can now update container apps to use these images:"
    echo "   - LibreChat: $ACR_LOGIN_SERVER/librechat:latest"
    echo "   - RAG API: $ACR_LOGIN_SERVER/rag-api:latest"
    
    # Ask if user wants to update container apps
    read -p "Do you want to update container apps with new images? (yes/no): " update_apps
    if [[ $update_apps == "yes" ]]; then
        echo "🔄 Updating LibreChat API container app..."
        az containerapp update \
            --name $LIBRECHAT_API_APP_NAME \
            --resource-group $RESOURCE_GROUP \
            --image $ACR_LOGIN_SERVER/librechat:latest
        
        if [[ -d "packages/api" ]]; then
            echo "🔄 Updating RAG API container app..."
            az containerapp update \
                --name $RAG_API_APP_NAME \
                --resource-group $RESOURCE_GROUP \
                --image $ACR_LOGIN_SERVER/rag-api:latest
        fi
        
        echo "✅ Container apps updated with new images!"
    fi
    exit 0
fi


# ------------------------------------------------------------
# ------------------------------------------------------------
# AZURE REVERT STEPS
# ------------------------------------------------------------
# ------------------------------------------------------------

# Prüfe ob --revert Parameter übergeben wurde
if [[ "${1:-}" == "--revert" ]]; then
    echo "🔄 Reverting Azure Bio Suisse AI Assistant Setup..."
    echo "⚠️  This will delete ALL resources in the resource group: $RESOURCE_GROUP"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    if [[ $confirm == "yes" ]]; then
        echo "🗑️  Deleting resource group: $RESOURCE_GROUP"
        az group delete \
            --name $RESOURCE_GROUP \
            --yes \
            --no-wait
        echo "✅ Resource group deletion initiated. This may take a few minutes."
        echo "💡 You can check the status with: az group show --name $RESOURCE_GROUP"
        exit 0
    else
        echo "❌ Operation cancelled."
        exit 1
    fi
fi


# ------------------------------------------------------------
# ------------------------------------------------------------
# AZURE SETUP STEPS
# ------------------------------------------------------------
# ------------------------------------------------------------

# ------------------------------------------------------------
# STEP 0: Check Requirements & Azure Login
# ------------------------------------------------------------
# Is Azure CLI installed?
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install first."
    exit 1
fi
# Login to Azure
az login

# ------------------------------------------------------------
# STEP 1: Create Azure Resource Group
# ------------------------------------------------------------
echo "🌍 Create Azure Ressource Group: $RESOURCE_GROUP"
az group create \
    --name $RESOURCE_GROUP \
    --location $AZURE_LOCATION

# ------------------------------------------------------------
# STEP 2: Create Azure Container Registry
# ------------------------------------------------------------
echo "🏦 Create Azure Container Registry: $ACR_NAME"
az acr create \
    --name $ACR_NAME \
    --resource-group $RESOURCE_GROUP \
    --sku Basic \
    --admin-enabled true

# ------------------------------------------------------------
# STEP 3: Create Log Analytics Workspace
# ------------------------------------------------------------
echo "📊 Create Log Analytics Workspace: $LOG_ANALYTICS_WORKSPACE"
az monitor log-analytics workspace create \
    --resource-group $RESOURCE_GROUP \
    --workspace-name $LOG_ANALYTICS_WORKSPACE \
    --location $AZURE_LOCATION

# ------------------------------------------------------------
# STEP 4: Create Azure Container App Environment
# ------------------------------------------------------------
echo "🌍 Create Azure Container App Environment: $ENVIRONMENT_NAME"
az containerapp env create \
    --name $ENVIRONMENT_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $AZURE_LOCATION \
    --logs-workspace-id $(az monitor log-analytics workspace show \
        --resource-group $RESOURCE_GROUP \
        --workspace-name $LOG_ANALYTICS_WORKSPACE \
        --query customerId -o tsv)

# ------------------------------------------------------------
# STEP 5: Create Azure Storage Account
# ------------------------------------------------------------
echo "💾 Create Azure Storage Account: $STORAGE_ACCOUNT_NAME"
az storage account create \
    --name $STORAGE_ACCOUNT_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $AZURE_LOCATION \
    --sku Standard_LRS \
    --kind StorageV2

# ------------------------------------------------------------
# STEP 6: Create Azure Key Vault
# ------------------------------------------------------------
echo "🔒 Create Azure Key Vault: $KEYVAULT_NAME"
az keyvault create \
    --name $KEYVAULT_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $AZURE_LOCATION



# ------------------------------------------------------------
# ------------------------------------------------------------
# CONTTAINER APPS DEPLOYMENT
# ------------------------------------------------------------
# ------------------------------------------------------------


# ------------------------------------------------------------
# STEP 7: Create MongoDB Container App (OPEN POINTS)
# ------------------------------------------------------------
echo "🍃 Create MongoDB Container App: $MONGO_APP_NAME"
az containerapp create \
    --name $MONGO_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --environment $ENVIRONMENT_NAME \
    --image mongo:latest \
    --target-port 27017 \
    --ingress internal \
    --env-vars MONGO_INITDB_ROOT_USERNAME=admin MONGO_INITDB_ROOT_PASSWORD=your-password

# ------------------------------------------------------------
# STEP 8: Create Meilisearch Container App
# ------------------------------------------------------------
echo "🔍 Create Meilisearch Container App: $MEILISEARCH_APP_NAME"
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
# STEP 9: Create Postgres Container App 
# ------------------------------------------------------------
echo "🐘 Create Postgres Container App: $POSTGRES_APP_NAME"
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
# STEP 10: Create RAG API Container App
# ------------------------------------------------------------
echo "🤖 Create RAG API Container App: $RAG_API_APP_NAME"
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
# STEP 11: Create LibreChat API Container App (MAIN APP)
# ------------------------------------------------------------
echo "📱 Create LibreChat API Container (Main App) App: $LIBRECHAT_API_APP_NAME"
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

# ------------------------------------------------------------
# STEP 12: Create Monitoring Container App
# ------------------------------------------------------------
echo "🔍 Create Monitoring Container App: $LIBRECHAT_API_APP_NAME"
az containerapp update \
    --name $LIBRECHAT_API_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --min-replicas 1 \
    --max-replicas 3 \
    --cpu 0.5 \
    --memory 1.0Gi
    