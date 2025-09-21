param redisName string = 'myBasicRedisCache'

var location = resourceGroup().location

resource redis 'Microsoft.Cache/Redis@2024-11-01' = {
  name: redisName
  location: location
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0  // 250MB capacity in Basic tier
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'  // New property for network security
  }
}
