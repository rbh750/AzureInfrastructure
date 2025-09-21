param serverName string
param adminUser string
@secure()
param adminPassword string

resource sqlServer 'Microsoft.Sql/servers@2024-05-01-preview' = {
  name: serverName
  location: resourceGroup().location
  properties: {
    administratorLogin: adminUser
    administratorLoginPassword: adminPassword
  }
}
