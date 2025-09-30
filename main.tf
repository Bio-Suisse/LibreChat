// main.tf

// =========== PROVIDER CONFIGURATION ===========
// Definiert den Azure Provider und dessen Version.
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

// =========== VARIABLES ===========
// Variablen für die Konfiguration, ähnlich den Bicep-Parametern.
variable "location" {
  description = "The Azure region for all resources."
  type        = string
  default     = "Switzerland North"
}

variable "base_name" {
  description = "The base name for all resources."
  type        = string
  default     = "bioaiassist"
}

// Lokale Variablen, die aus den Input-Variablen abgeleitet werden.
locals {
  resource_group_name         = "${var.base_name}-rg"
  acr_name                    = "${var.base_name}acr"
  log_analytics_workspace_name = "${var.base_name}-logs"
  container_app_environment_name = "${var.base_name}-env"
  storage_account_name        = lower(replace(var.base_name, "-", "")) // Storage names need to be lowercase alphanumeric
  key_vault_name              = "${var.base_name}kv"
}

// =========== RESOURCE DEFINITIONS ===========

# STEP 1: Create Azure Resource Group
resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
}

# STEP 2: Create Azure Container Registry
resource "azurerm_container_registry" "main" {
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
}

# STEP 3: Create Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = local.log_analytics_workspace_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
}

# STEP 4: Create Azure Container App Environment
resource "azurerm_container_app_environment" "main" {
  name                       = local.container_app_environment_name
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

# STEP 5: Create Azure Storage Account
resource "azurerm_storage_account" "main" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# STEP 6: Create Azure Key Vault and Secrets
resource "azurerm_key_vault" "main" {
  name                = local.key_vault_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  soft_delete_retention_days = 7

  // Wichtig: Der User/Service Principal, der Terraform ausführt, muss Rechte haben, Secrets zu setzen.
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    secret_permissions = [
      "Set", "Get", "Delete", "Purge", "List"
    ]
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault_secret" "mongo_password" {
  name         = "mongo-password"
  value        = "YourStrongMongoPassword123!" // ÄNDERE DIESEN WERT!
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "meili_master_key" {
  name         = "meili-master-key"
  value        = "YourStrongMeiliMasterKey456!" // ÄNDERE DIESEN WERT!
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-password"
  value        = "YourStrongPostgresPassword789!" // ÄNDERE DIESEN WERT!
  key_vault_id = azurerm_key_vault.main.id
}


# =========== CONTAINER APPS DEPLOYMENT ===========

# STEP 7: Create MongoDB Container App
resource "azurerm_container_app" "mongo" {
  name                         = "bio-ai-mongodb"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  
  identity {
    type = "SystemAssigned"
  }

  secret {
    name      = "mongo-root-password"
    key_vault_secret_id = azurerm_key_vault_secret.mongo_password.id
    identity  = "SystemAssigned"
  }

  template {
    container {
      name   = "mongodb"
      image  = "mongo:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "MONGO_INITDB_ROOT_USERNAME"
        value = "admin"
      }
      env {
        name        = "MONGO_INITDB_ROOT_PASSWORD"
        secret_name = "mongo-root-password"
      }
    }
  }

  ingress {
    internal_only = true
    target_port   = 27017
  }
}

# STEP 8: Create Meilisearch Container App
resource "azurerm_container_app" "meilisearch" {
  name                         = "bio-ai-meilisearch"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  secret {
    name = "meili-master-key-secret"
    key_vault_secret_id = azurerm_key_vault_secret.meili_master_key.id
    identity = "SystemAssigned"
  }

  template {
    container {
      name   = "meilisearch"
      image  = "getmeili/meilisearch:v1.12.3"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "MEILI_NO_ANALYTICS"
        value = "true"
      }
      env {
        name        = "MEILI_MASTER_KEY"
        secret_name = "meili-master-key-secret"
      }
    }
  }

  ingress {
    internal_only = true
    target_port   = 7700
  }
}

# STEP 9: Create Postgres Container App
resource "azurerm_container_app" "postgres" {
  name                         = "bio-ai-postgres"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }
  
  secret {
    name = "postgres-password-secret"
    key_vault_secret_id = azurerm_key_vault_secret.postgres_password.id
    identity = "SystemAssigned"
  }

  template {
    container {
      name   = "postgres"
      image  = "pgvector/pgvector:0.8.0-pg15-trixie"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "POSTGRES_DB"
        value = "mydatabase"
      }
      env {
        name  = "POSTGRES_USER"
        value = "myuser"
      }
      env {
        name = "POSTGRES_PASSWORD"
        secret_name = "postgres-password-secret"
      }
    }
  }

  ingress {
    internal_only = true
    target_port   = 5432
  }
}

# STEP 10: Create RAG API Container App
resource "azurerm_container_app" "rag_api" {
  name                         = "bio-ai-rag-api"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  template {
    container {
      name   = "rag-api"
      image  = "ghcr.io/danny-avila/librechat-rag-api-dev-lite:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      
      env {
        name  = "DB_HOST"
        value = "vectordb"
      }
      env {
        name  = "RAG_PORT"
        value = "8000"
      }
    }
  }

  ingress {
    internal_only = true
    target_port   = 8000
  }
}

# STEP 11 & 12: Create LibreChat API Container App
resource "azurerm_container_app" "librechat_api" {
  name                         = "bio-ai-librechat-api"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "librechat-api"
      image  = "ghcr.io/danny-avila/librechat-dev:latest"
      cpu    = 0.5
      memory = "1.0Gi"

      env { name = "HOST", value = "0.0.0.0" }
      env { name = "PORT", value = "3080" }
      env { name = "MONGO_URI", value = "mongodb://admin:${azurerm_key_vault_secret.mongo_password.value}@${azurerm_container_app.mongo.name}:27017/LibreChat"}
      env { name = "MEILI_HOST", value = "http://${azurerm_container_app.meilisearch.name}:7700" }
      env { name = "RAG_PORT", value = "8000" }
      env { name = "RAG_API_URL", value = "http://${azurerm_container_app.rag_api.name}:8000" }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 3080
  }
}

# Key Vault Access Policies für die Container Apps
resource "azurerm_key_vault_access_policy" "mongo" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_container_app.mongo.identity[0].principal_id

  secret_permissions = ["Get"]
}

resource "azurerm_key_vault_access_policy" "meilisearch" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_container_app.meilisearch.identity[0].principal_id

  secret_permissions = ["Get"]
}

resource "azurerm_key_vault_access_policy" "postgres" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_container_app.postgres.identity[0].principal_id

  secret_permissions = ["Get"]
}