param apimServiceName string
param privateApiDisplayName string
param privateApiName string
param publicApiDisplayName string
param publicApiName string
param publisherEmail string
param publisherName string
param privateSubscriptionName string
param publicSubscriptionName string
param privateSubscriptionPrimaryKey string
param privateSubscriptionSecondaryKey string 
param publicSubscriptionPrimaryKey string
param publicSubscriptionSecondaryKey string 

var location = resourceGroup().location
var publicApiWebServiceUrl = 'https://${publicApiName}'
var privateApiWebServiceUrl = 'https://${privateApiName}'

// publicApiName = 'wwtp-dev-web-public-api'
// publicApiDisplayName = 'Wwtp Dev Web Public'

resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: apimServiceName
  location: location
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource apimPublicApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: publicApiName
  parent: apimService
  properties: {
    serviceUrl: publicApiWebServiceUrl
    displayName: publicApiDisplayName
    path: publicApiName
    protocols: [
      'https'
    ]
  }
}

resource apimPrivateApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: privateApiName
  parent: apimService
  properties: {
    serviceUrl: privateApiWebServiceUrl
    displayName: privateApiDisplayName
    path: privateApiName
    protocols: [
      'https'
    ]
  }
}

resource privateApiSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  name: privateSubscriptionName
  parent: apimService
  dependsOn: [
    apimPrivateApi
  ]
  properties: {
    scope: '/apis/${privateApiName}'
    displayName: privateSubscriptionName
    primaryKey: privateSubscriptionPrimaryKey
    secondaryKey: privateSubscriptionSecondaryKey
    state: 'active'
  }
}


resource publicApiSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  name: publicSubscriptionName
  parent: apimService
  dependsOn: [
    apimPublicApi
  ]
  properties: {
    scope: '/apis/${publicApiName}'
    displayName: publicSubscriptionName
    primaryKey: publicSubscriptionPrimaryKey
    secondaryKey: publicSubscriptionSecondaryKey
    state: 'active'
  }
}

