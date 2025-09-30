// main.bicep

// =========== PARAMETERS ===========
// Diese Werte können beim Ausführen des Skripts angepasst werden.
@description('The Azure region where all resources should be deployed.')
param location string = 'switzerlandnorth'

@description('The base name for all resources, used as a prefix.')
param baseName string = 'bioaiassist'

// =========== VARIABLES ===========
// Aus den Parametern abgeleitete Namen für die Ressourcen.
var resourceGroupName = '${baseName}-rg'
var acrName = '${baseName}acr'
var logAnalyticsWorkspaceName = '${baseName}-logs'
var environmentName = '${baseName}-env'
var storageAccountName = baseName
var keyVaultName = '${baseName}kv'

// Namen für die Container Apps
var mongoAppName = 'bio-ai-mongodb'
var meilisearchAppName = 'bio-ai-meilisearch'
var postgresAppName = 'bio-ai-postgres'
var ragApiAppName = 'bio-ai-rag-api'
var librechatApiAppName = 'bio-ai-librechat-api'

// =========== RESOURCE DEPLOYMENT ===========

// Das targetScope 'subscription' erlaubt Bicep, die Ressourcengruppe selbst zu erstellen.
targetScope = 'subscription'

// STEP 1: Create Azure Resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

// Alle folgenden Ressourcen werden innerhalb der oben erstellten Ressourcengruppe bereitgestellt.
// Das 'module' ist eine saubere Methode, um den Geltungsbereich zu wechseln.
module main 'main.resources.bicep' = {
  scope: resourceGroup // Wechselt den Geltungsbereich auf die neue Ressourcengruppe
  name: 'deployResources'
  params: {
    location: location
    acrName: acrName
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    environmentName: environmentName
    storageAccountName: storageAccountName
    keyVaultName: keyVaultName
    mongoAppName: mongoAppName
    meilisearchAppName: meilisearchAppName
    postgresAppName: postgresAppName
    ragApiAppName: ragApiAppName
    librechatApiAppName: librechatApiAppName
  }
}