// main.resources.bicep

// Parameter, die von main.bicep übergeben werden
param location string
param acrName string
param logAnalyticsWorkspaceName string
param environmentName string
param storageAccountName string
param keyVaultName string
param mongoAppName string
param meilisearchAppName string
param postgresAppName string
param ragApiAppName string
param librechatApiAppName string

// Hier werden die Secrets definiert, die wir im Key Vault speichern.
// ÄNDERE DIESE WERTE!
var mongoPassword = 'YourStrongMongoPassword123!'
var meiliMasterKey = 'YourStrongMeiliMasterKey456!'
var postgresPassword = 'YourStrongPostgresPassword789!'

// STEP 2: Create Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

// STEP 3: Create Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

// STEP 4: Create Azure Container App Environment
resource containerAppEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// STEP 5: Create Azure Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

// STEP 6: Create Azure Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    // Wir müssen dem Container App Environment Zugriff auf den Key Vault geben
    accessPolicies: [] 
    enableSoftDelete: true
  }
}

// Secrets im Key Vault erstellen
resource mongoSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'mongo-password'
  properties: {
    value: mongoPassword
  }
}
resource meiliSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'meili-master-key'
  properties: {
    value: meiliMasterKey
  }
}
resource postgresSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'postgres-password'
  properties: {
    value: postgresPassword
  }
}


// =========== CONTAINER APPS DEPLOYMENT ===========
// Jede Container App wird als separate Ressource definiert.
// Die 'dependsOn' Klausel stellt sicher, dass der Key Vault existiert, bevor die Apps erstellt werden.

// STEP 7: Create MongoDB Container App
resource mongoApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: mongoAppName
  location: location
  dependsOn: [ keyVault ]
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        targetPort: 27017
        internal: true
      }
      // Secrets werden aus dem Key Vault referenziert
      secrets: [
        {
          name: 'mongo-root-password'
          keyVaultUrl: mongoSecret.properties.secretUri
          identity: 'system' // Benötigt eine System Managed Identity für die App
        }
      ]
    }
    template: {
      containers: [
        {
          image: 'mongo:latest'
          name: 'mongodb'
          env: [
            {
              name: 'MONGO_INITDB_ROOT_USERNAME'
              value: 'admin'
            }
            {
              name: 'MONGO_INITDB_ROOT_PASSWORD'
              secretRef: 'mongo-root-password'
            }
          ]
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// STEP 8: Create Meilisearch Container App
resource meilisearchApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: meilisearchAppName
  location: location
  dependsOn: [ keyVault ]
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        targetPort: 7700
        internal: true
      }
      secrets: [
        {
          name: 'meili-master-key-secret'
          keyVaultUrl: meiliSecret.properties.secretUri
          identity: 'system'
        }
      ]
    }
    template: {
      containers: [
        {
          image: 'getmeili/meilisearch:v1.12.3'
          name: 'meilisearch'
          env: [
            {
              name: 'MEILI_NO_ANALYTICS'
              value: 'true'
            }
            {
              name: 'MEILI_MASTER_KEY'
              secretRef: 'meili-master-key-secret'
            }
          ]
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// STEP 9: Create Postgres Container App
resource postgresApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: postgresAppName
  location: location
  dependsOn: [ keyVault ]
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        targetPort: 5432
        internal: true
      }
      secrets: [
        {
          name: 'postgres-password-secret'
          keyVaultUrl: postgresSecret.properties.secretUri
          identity: 'system'
        }
      ]
    }
    template: {
      containers: [
        {
          image: 'pgvector/pgvector:0.8.0-pg15-trixie'
          name: 'postgres'
          env: [
            {
              name: 'POSTGRES_DB'
              value: 'mydatabase'
            }
            {
              name: 'POSTGRES_USER'
              value: 'myuser'
            }
            {
              name: 'POSTGRES_PASSWORD'
              secretRef: 'postgres-password-secret'
            }
          ]
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// STEP 10: Create RAG API Container App
resource ragApiApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: ragApiAppName
  location: location
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        targetPort: 8000
        internal: true
      }
    }
    template: {
      containers: [
        {
          image: 'ghcr.io/danny-avila/librechat-rag-api-dev-lite:latest'
          name: 'rag-api'
          env: [
            {
              name: 'DB_HOST'
              value: 'vectordb'
            }
            {
              name: 'RAG_PORT'
              value: '8000'
            }
          ]
        }
      ]
    }
  }
}

// STEP 11 & 12: Create LibreChat API Container App (MAIN APP with Monitoring)
resource librechatApiApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: librechatApiAppName
  location: location
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        // 'external' macht die App aus dem Internet erreichbar. Ändere zu 'internal: true', wenn nicht gewünscht.
        external: true
        targetPort: 3080
      }
    }
    template: {
      containers: [
        {
          image: 'ghcr.io/danny-avila/librechat-dev:latest'
          name: 'librechat-api'
          resources: {
            cpu: 0.5
            memory: '1.0Gi'
          }
          env: [
            {
              name: 'HOST'
              value: '0.0.0.0'
            }
            {
              name: 'PORT'
              value: '3080'
            }
            {
              name: 'MONGO_URI'
              value: 'mongodb://admin:${mongoPassword}@${mongoAppName}:27017/LibreChat' // Das Secret muss hier direkt eingefügt werden, da es Teil einer Verbindungszeichenfolge ist.
            }
            {
              name: 'MEILI_HOST'
              value: 'http://${meilisearchAppName}:7700'
            }
            {
              name: 'RAG_PORT'
              value: '8000'
            }
            {
              name: 'RAG_API_URL'
              value: 'http://${ragApiAppName}:8000'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

// Key Vault Access Policy Zuweisung, damit die Container Apps die Secrets lesen können
// Dies wird erst konfiguriert, nachdem die Apps ihre Managed Identities erhalten haben
resource kvMongoAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: mongoApp.identity.principalId
        permissions: {
          secrets: [ 'get' ]
        }
      }
      {
        tenantId: subscription().tenantId
        objectId: meilisearchApp.identity.principalId
        permissions: {
          secrets: [ 'get' ]
        }
      }
      {
        tenantId: subscription().tenantId
        objectId: postgresApp.identity.principalId
        permissions: {
          secrets: [ 'get' ]
        }
      }
    ]
  }
}