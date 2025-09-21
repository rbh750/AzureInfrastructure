// To validate this file from Windows cmd prompt(adm) run:
// az login --tenant cbc31bc0-a781-4712-809b-3b404c5e19e2
// az bicep build --file E:\GitRepos\Ssmp\WebApps\WebApp.Wwtp\AzureInfrastructure\Bicep\WebAppInfra.bicep

// Falta: app insights, cosmos, apim y SQL (pool para prod y 2 single dbs para dev)
param appInsightsName string
param appServiceName string
param appServicePlanName string
param emailContainerName string
param keyVaultName string
param mapLocation string
param mapName string
param privateStorageAccountName string
param publicStorageAccountName string
param tenantId string

var location = resourceGroup().location

var appServicePlanSku = {
  name: 'S1'
  tier: 'Standard'
}

var commonAppSettings = {
  ExecutionEnvironment: 'AzureWebApp'
  WEBSITE_SWAP_ENABLE_APP_INIT: '1'
  WEBSITE_SWAP_SHOW_PROGRESS: '1'
  WEBSITE_SWAP_WARMUP_PING_COUNT: '10'
  WEBSITE_SWAP_WARMUP_PING_ENABLED: '1'
  WEBSITE_SWAP_WARMUP_PING_PATH: '/healthcheck'
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2024-12-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    softDeleteRetentionInDays: 90
    enableRbacAuthorization: true
    publicNetworkAccess: 'Enabled'
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: appServicePlanName
  location: location
  sku: appServicePlanSku
  properties: {
    reserved: false // Windows
  }
}

// Define the Web App, linked to the App Service Plan
resource appService 'Microsoft.Web/sites@2024-04-01' = {
  name: appServiceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      netFrameworkVersion: 'v9.0'
      use32BitWorkerProcess: false // false = 64-bit platform
    }
  }
}

// Define and configure the deployment slots only if useDeploymentSlots is true
resource stagingSlot 'Microsoft.Web/sites/slots@2024-04-01' = {
  parent: appService
  name: 'staging'
  location: location
  identity: {
    type: 'SystemAssigned'
  }  
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      netFrameworkVersion: 'v9.0'
      use32BitWorkerProcess: false // false = 64-bit platform
    }
  }
}

resource appServiceAppSettings 'Microsoft.Web/sites/config@2024-04-01' = {
  parent: appService
  name: 'appsettings'
  properties: commonAppSettings
}

resource stagingSlotAppSettings 'Microsoft.Web/sites/slots/config@2024-04-01' = {
  parent: stagingSlot
  name: 'appsettings'
  properties: commonAppSettings
}
resource privateStorageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: privateStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    largeFileSharesState: 'Enabled'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    isHnsEnabled: false
    isNfsV3Enabled: false
  }
}

resource privateBlobService 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  parent: privateStorageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2024-01-01' = {
  parent: privateStorageAccount
  name: 'default'
  properties: {}
}

resource publicStorageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: publicStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    largeFileSharesState: 'Enabled'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    isHnsEnabled: false
    isNfsV3Enabled: false
  }
}

resource publicBlobService 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  parent: publicStorageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource publicBlobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  parent: publicBlobService
  name: emailContainerName
  properties: {
    publicAccess: 'Blob'
  }
}

resource azureMap 'Microsoft.Maps/accounts@2024-07-01-preview' = {
  name: mapName
  location: mapLocation
  sku: {
    name: 'G2'
  }
  kind: 'Gen2'
  identity: {
    type: 'None'
  }
  properties: {
    disableLocalAuth: false
    cors: {
      corsRules: [
        {
          allowedOrigins: []
        }
      ]
    }
    publicNetworkAccess: 'enabled'
    locations: []
  }
}

output applicationInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString
output appServiceClientId string = appService.identity.principalId
output appServiceSlotClientId string = stagingSlot.identity.principalId 
output appServicePlanId string = appServicePlan.id
output keyVaultName string = keyVault.name
output privateStorageAccountName string = privateStorageAccount.name
output privateStorageAccountPrimaryEndpoints object = privateStorageAccount.properties.primaryEndpoints
output publicStorageAccountName string = publicStorageAccount.name
output publicStorageAccountPrimaryEndpoints object = publicStorageAccount.properties.primaryEndpoints
output azureMapPrimaryKey string = listKeys(azureMap.id, '2024-01-01-preview').primaryKey
