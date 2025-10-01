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

// Sicherheitsvariablen für Passwörter
variable "mongo_password" {
  description = "MongoDB root password"
  type        = string
  sensitive   = true
  default     = null
}

variable "meili_master_key" {
  description = "Meilisearch master key"
  type        = string
  sensitive   = true
  default     = null
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
  default     = null
}

variable "openai_api_key" {
  description = "OpenAI API Key for LibreChat"
  type        = string
  sensitive   = true
  default     = null
}

// Lokale Variablen, die aus den Input-Variablen abgeleitet werden.
locals {
  resource_group_name         = "${var.base_name}-rg"
  acr_name                    = "${var.base_name}acr"
  log_analytics_workspace_name = "${var.base_name}-logs"
  container_app_environment_name = "${var.base_name}-env"
  storage_account_name        = lower(replace(var.base_name, "-", "")) // Storage names need to be lowercase alphanumeric
  key_vault_name              = "${var.base_name}kv"
  
  // Generiere sichere Passwörter falls nicht angegeben
  mongo_password_final        = var.mongo_password != null ? var.mongo_password : "Mongo${random_password.mongo_password.result}"
  meili_master_key_final      = var.meili_master_key != null ? var.meili_master_key : "Meili${random_password.meili_key.result}"
  postgres_password_final     = var.postgres_password != null ? var.postgres_password : "Postgres${random_password.postgres_password.result}"
}

// Zufällige Passwörter generieren falls keine angegeben werden
resource "random_password" "mongo_password" {
  length  = 16
  special = true
}

resource "random_password" "meili_key" {
  length  = 32
  special = false
}

resource "random_password" "postgres_password" {
  length  = 16
  special = true
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

# STEP 4: Create VNet for Container Apps
resource "azurerm_virtual_network" "main" {
  name                = "${var.base_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "container_apps" {
  name                 = "${var.base_name}-container-apps-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
  
  delegation {
    name = "Microsoft.App.environments"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# STEP 5: Create Azure Container App Environment with VNet
resource "azurerm_container_app_environment" "main" {
  name                       = local.container_app_environment_name
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  infrastructure_subnet_id   = azurerm_subnet.container_apps.id
  internal_load_balancer_enabled = true
}

# STEP 6: Create Azure Storage Account
resource "azurerm_storage_account" "main" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Storage Shares für persistente Daten
resource "azurerm_storage_share" "mongo_data" {
  name                 = "mongo-data"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 10
}

resource "azurerm_storage_share" "postgres_data" {
  name                 = "postgres-data"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 10
}

resource "azurerm_storage_share" "meili_data" {
  name                 = "meili-data"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 5
}

# STEP 7: Create Azure Key Vault and Secrets
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
  value        = local.mongo_password_final
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "meili_master_key" {
  name         = "meili-master-key"
  value        = local.meili_master_key_final
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-password"
  value        = local.postgres_password_final
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "openai_api_key" {
  name         = "openai-api-key"
  value        = var.openai_api_key
  key_vault_id = azurerm_key_vault.main.id
}


# =========== CONTAINER APPS DEPLOYMENT ===========

# STEP 8: Create MongoDB Container App
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

      liveness_probe {
        http_get {
          path = "/"
          port = 27017
        }
        initial_delay_seconds = 30
        period_seconds        = 10
        timeout_seconds       = 5
        failure_threshold     = 3
      }

      readiness_probe {
        http_get {
          path = "/"
          port = 27017
        }
        initial_delay_seconds = 10
        period_seconds        = 5
        timeout_seconds       = 3
        failure_threshold     = 3
      }
    }
    
    volume {
      name         = "mongo-data"
      storage_type = "AzureFile"
      storage_name = azurerm_storage_share.mongo_data.name
    }
  }

  ingress {
    external_enabled = false
    target_port      = 27017
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }
}

# STEP 9: Create Meilisearch Container App
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

      liveness_probe {
        http_get {
          path = "/health"
          port = 7700
        }
        initial_delay_seconds = 30
        period_seconds        = 10
        timeout_seconds       = 5
        failure_threshold     = 3
      }

      readiness_probe {
        http_get {
          path = "/health"
          port = 7700
        }
        initial_delay_seconds = 10
        period_seconds        = 5
        timeout_seconds       = 3
        failure_threshold     = 3
      }
    }
    
    volume {
      name         = "meili-data"
      storage_type = "AzureFile"
      storage_name = azurerm_storage_share.meili_data.name
    }
  }

  ingress {
    external_enabled = false
    target_port      = 7700
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }
}

# STEP 10: Create Postgres Container App
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

      liveness_probe {
        exec {
          command = ["pg_isready", "-U", "myuser", "-d", "mydatabase"]
        }
        initial_delay_seconds = 30
        period_seconds        = 10
        timeout_seconds       = 5
        failure_threshold     = 3
      }

      readiness_probe {
        exec {
          command = ["pg_isready", "-U", "myuser", "-d", "mydatabase"]
        }
        initial_delay_seconds = 10
        period_seconds        = 5
        timeout_seconds       = 3
        failure_threshold     = 3
      }
    }
    
    volume {
      name         = "postgres-data"
      storage_type = "AzureFile"
      storage_name = azurerm_storage_share.postgres_data.name
    }
  }

  ingress {
    external_enabled = false
    target_port      = 5432
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }
}

# STEP 11: Create RAG API Container App
resource "azurerm_container_app" "rag_api" {
  name                         = "bio-ai-rag-api"
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
      name   = "rag-api"
      image  = "ghcr.io/danny-avila/librechat-rag-api-dev-lite:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      
      env {
        name  = "DB_HOST"
        value = azurerm_container_app.postgres.latest_revision_fqdn
      }
      env {
        name  = "DB_PORT"
        value = "5432"
      }
      env {
        name  = "DB_NAME"
        value = "mydatabase"
      }
      env {
        name  = "DB_USER"
        value = "myuser"
      }
      env {
        name        = "DB_PASSWORD"
        secret_name = "postgres-password-secret"
      }
      env {
        name  = "RAG_PORT"
        value = "8000"
      }

      liveness_probe {
        http_get {
          path = "/health"
          port = 8000
        }
        initial_delay_seconds = 30
        period_seconds        = 10
        timeout_seconds       = 5
        failure_threshold     = 3
      }

      readiness_probe {
        http_get {
          path = "/health"
          port = 8000
        }
        initial_delay_seconds = 10
        period_seconds        = 5
        timeout_seconds       = 3
        failure_threshold     = 3
      }
    }
  }

  ingress {
    external_enabled = false
    target_port      = 8000
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }
}

# STEP 12: Create LibreChat API Container App
resource "azurerm_container_app" "librechat_api" {
  name                         = "bio-ai-librechat-api"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  secret {
    name = "openai-api-key-secret"
    key_vault_secret_id = azurerm_key_vault_secret.openai_api_key.id
    identity = "SystemAssigned"
  }

  secret {
    name = "mongo-password-secret"
    key_vault_secret_id = azurerm_key_vault_secret.mongo_password.id
    identity = "SystemAssigned"
  }

  secret {
    name = "meili-master-key-secret"
    key_vault_secret_id = azurerm_key_vault_secret.meili_master_key.id
    identity = "SystemAssigned"
  }

  template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "librechat-api"
      image  = "ghcr.io/danny-avila/librechat-dev:latest"
      cpu    = 0.5
      memory = "1.0Gi"

      # Basic Configuration
      env {
        name  = "HOST"
        value = "0.0.0.0"
      }
      env {
        name  = "PORT"
        value = "3080"
      }
      env {
        name  = "NODE_ENV"
        value = "production"
      }

      # MongoDB Configuration
      env {
        name  = "MONGO_URI"
        value = "mongodb://admin:${local.mongo_password_final}@${azurerm_container_app.mongo.latest_revision_fqdn}:27017/LibreChat"
      }

      # Meilisearch Configuration
      env {
        name  = "MEILI_HOST"
        value = "http://${azurerm_container_app.meilisearch.latest_revision_fqdn}:7700"
      }
      env {
        name  = "MEILI_HTTP_ADDR"
        value = "${azurerm_container_app.meilisearch.latest_revision_fqdn}:7700"
      }
      env {
        name        = "MEILI_MASTER_KEY"
        secret_name = "meili-master-key-secret"
      }

      # RAG API Configuration
      env {
        name  = "RAG_API_URL"
        value = "http://${azurerm_container_app.rag_api.latest_revision_fqdn}:8000"
      }

      # OpenAI Configuration
      env {
        name        = "OPENAI_API_KEY"
        secret_name = "openai-api-key-secret"
      }

      # Domain Configuration
      env {
        name  = "DOMAIN_CLIENT"
        value = "https://${azurerm_container_app.librechat_api.latest_revision_fqdn}"
      }
      env {
        name  = "DOMAIN_SERVER"
        value = "https://${azurerm_container_app.librechat_api.latest_revision_fqdn}"
      }

      # Additional LibreChat Configuration
      env {
        name  = "ALLOW_REGISTRATION"
        value = "true"
      }
      env {
        name  = "ALLOW_SOCIAL_LOGIN"
        value = "false"
      }
      env {
        name  = "APP_TITLE"
        value = "Bio Suisse AI Assistant"
      }
      env {
        name  = "DEBUG_CONSOLE"
        value = "false"
      }

      liveness_probe {
        http_get {
          path = "/api/health"
          port = 3080
        }
        initial_delay_seconds = 60
        period_seconds        = 30
        timeout_seconds       = 10
        failure_threshold     = 3
      }

      readiness_probe {
        http_get {
          path = "/api/health"
          port = 3080
        }
        initial_delay_seconds = 30
        period_seconds        = 10
        timeout_seconds       = 5
        failure_threshold     = 3
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 3080
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
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

resource "azurerm_key_vault_access_policy" "rag_api" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_container_app.rag_api.identity[0].principal_id

  secret_permissions = ["Get"]
}

resource "azurerm_key_vault_access_policy" "librechat" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_container_app.librechat_api.identity[0].principal_id

  secret_permissions = ["Get"]
}

# =========== OUTPUTS ===========
output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.main.name
}

output "container_app_environment_name" {
  description = "Name of the container app environment"
  value       = azurerm_container_app_environment.main.name
}

output "librechat_url" {
  description = "URL of the LibreChat application"
  value       = "https://${azurerm_container_app.librechat_api.latest_revision_fqdn}"
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "key_vault_name" {
  description = "Name of the key vault"
  value       = azurerm_key_vault.main.name
}