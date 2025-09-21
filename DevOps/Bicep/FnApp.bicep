param appServicePlanId string
param privateFunctionAppName string
param publicFunctionAppName string
param storageAccountName string

var location = resourceGroup().location

var functionAppSettings = [
  {
    name: 'Azure:ExecutionEnvironment'
    value: 'AzureFn'
  }
  {
    name: 'AzureWebJobsStorage'
    value: storageAccount.properties.primaryEndpoints.blob
  }
  {
    name: 'FUNCTIONS_EXTENSION_VERSION'
    value: '~4'
  }
  {
    name: 'FUNCTIONS_WORKER_RUNTIME'
    value: 'dotnet-isolated'
  }
  {
    name: 'DOTNET_VERSION'
    value: '9.0'
  }
]

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: storageAccountName
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

resource privateFunctionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: privateFunctionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    reserved: false // Indicates Windows hosting
    serverFarmId: appServicePlanId
    siteConfig: {
      appSettings: functionAppSettings
    }
  }
}

resource publicFunctionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: publicFunctionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    reserved: false // Indicates Windows hosting
    serverFarmId: appServicePlanId
    siteConfig: {
      appSettings: functionAppSettings
    }
  }
}

resource privateStagingSlot 'Microsoft.Web/sites/slots@2024-04-01' = {
  parent: privateFunctionApp
  name: 'staging'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    siteConfig: {
      appSettings: functionAppSettings
    }
  }
}

resource publicStagingSlot 'Microsoft.Web/sites/slots@2024-04-01' = {
  parent: publicFunctionApp
  name: 'staging'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    siteConfig: {
      appSettings: functionAppSettings
    }
  }
}

output privateFunctionAppClientId string = privateFunctionApp.identity.principalId
output privateFunctionAppId string = privateFunctionApp.id
output publicFunctionAppClientId string = publicFunctionApp.identity.principalId
output publicFunctionAppId string = publicFunctionApp.id

output privateStagingSlotClientId string = privateStagingSlot.identity.principalId
output privateStagingSlotId string = privateStagingSlot.id
output publicStagingSlotClientId string = publicStagingSlot.identity.principalId
output publicStagingSlotId string = publicStagingSlot.id
