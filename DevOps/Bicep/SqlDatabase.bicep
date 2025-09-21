param databaseName string
param serverName string
param serviceTier string

var location = resourceGroup().location

resource sqlDatabase 'Microsoft.Sql/servers/databases@2024-05-01-preview' = {
  name: '${serverName}/${databaseName}'
  location: location
  sku: {
    name: serviceTier
  }
  properties: {
  }
}

// output databaseResourceId string = sqlDatabase.id
