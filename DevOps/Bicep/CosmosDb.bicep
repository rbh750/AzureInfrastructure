param cosmosAccount string
param cosmosDatabase string

var location = resourceGroup().location

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2022-02-15-preview' = {
  name: cosmosAccount
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2022-02-15-preview' = {
  parent: cosmosDbAccount
  name: cosmosDatabase
  properties: {
    resource: {
      id: cosmosDatabase
    }
  }
}

output cosmosDbConnectionString string = 'AccountEndpoint=${cosmosDbAccount.properties.documentEndpoint};AccountKey=${listKeys(cosmosDbAccount.id, '2021-04-15').primaryMasterKey};'



