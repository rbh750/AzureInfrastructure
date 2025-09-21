# ***************************************************************************************************************************
# Modify the parameters listed bellow.
# ***************************************************************************************************************************

# The tenant and subscription ID where all resources will be deployed.
$tenantId = "xxx"
$subscriptionId = "xxx"

# Entra App used by all scripts to authenticate and deploy resources to Azure.
# It must be created in the Azure portal: Azure Active Directory > App registrations > New registration
# The app requires the following API permissions:
# |-------------------------------|-------------|-----------------------------------------------------------|------------------------|
# | API / Permissions name        | Type        | Description                                               | Admin consent required |
# |-------------------------------|-------------|-----------------------------------------------------------|------------------------|
# | Application.Read.All          | Application | Read all applications                                     | Yes                    |
# | Application.ReadWrite.All     | Application | Read and write all applications                           | Yes                    |
# | Application.ReadWrite.OwnedBy | Delegated   | Read and write applications that this app creates or owns | No                     |
# | Directory.Read.All            | Application | Read directory data                                       | Yes                    |
# | Directory.ReadWrite.All       | Application | Read and write directory data                             | Yes                    |
# | offline_access                | Delegated   | Maintain access to data you have given it access to       | No                     |
# | openid                        | Delegated   | Sign users in                                             | No                     |
# | profile                       | Delegated   | View users' basic profile                                 | No                     |
# | User.Read                     | Delegated   | Sign in and read user profile                             | No                     |
# |-------------------------------|-------------|-----------------------------------------------------------|------------------------|
$authClientId = "xxx" 
$authClientSecret = "xxx"

# Azure DevOps Service Connection Entra App.
# Allows DevOps pipelines securely interact with Azure resources—without manual authentication every time.
# It must be created from DevOps Project > Project Settings > Service connections > New service connection > Azure Resource Manager 
$DevOpsServiceCnnEntraAppClientId = "xxx"

# Use 'P' for purge or 'R' for restoring secrets.
$keyVaultRestoreOptions = "R"

# A prefix for all resources deployed to Azure.
# Don't change this value as the scripts are configured to use "Wwtp".
$prefix = "wwtp"

# Each resource name includes a counter to allow redeployment. 
# This is necessary because certain resources, like Key Vaults, may need to be purged before they can be recreated with the same name.
$suffix = "-01"

# The Excel file located at PowerShell\SettingsIndex.xlsx serves as the single source of truth for all web app application settings. 
# It contains configuration values for multiple environments, organized by an Environment column. 
# This parameter specifies which column to reference when retrieving settings for a specific deployment target.
$environment = "dev" 

# ***************************************************************************************************************************
# Do not modify the parameters listed bellow.
# ***************************************************************************************************************************

$apimPrivateApiDisplayName = "$prefix Dev Web Private"
$apimPrivateApiName = "$prefix-dev-private-fn$suffix"
$apimPrivateSubscriptionName = "X-$prefix-Dev-Web-Private-Subscription"
$apimPublicApiDisplayName = "$prefix Dev Web Public"
$apimPublicApiName = "$prefix-dev-public-fn$suffix"
$apimPublicSubscriptionName = "X-$prefix-Dev-Web-Public-Subscription"
$apimPublisherEmail = "myemail@test.com"
$apimPublisherName = "We Want To Party"
$apimServiceName = "$prefix-dev-apim$suffix"
$appInsightsResourceName = "$prefix-dev-ain$suffix"
$appservicePlanName = "$prefix-dev-web-splan$suffix"
$appserviceName = "$prefix-dev-web-app$suffix"
$CosmosAccount = "$prefix-dev-cosmos-server$suffix"
$CosmosDataBase = "$prefix-db$suffix"
$emailContainerName = "email-templates"

# The solution that is using these resources requires several Entra App Registrations.
# Each app registration serves a specific purpose, such as enabling authentication for different parts of the application.
$entraAppInsightsApName = "$prefix-Backend-AppInsights$suffix"
$entraAppInsightsApNote = "This application enables the AppInsightsQueryService to authenticate and access Application Insights"
$entraIntegrationApName = "$prefix-Backend-Integration$suffix"
$entraIntegrationApNote = "This application enables APIM to authenticate and access the function apps"
$entraWebUiClientApName = "$prefix-Frontend-Client$suffix"
$entraWebUiClientApNote = "This application enables clients to authenticate and access the website"
$entraWebUiVendorApName = "$prefix-Frontend-Vendor$suffix"
$entraWebUiVendorApNote = "This application enables vendors to authenticate and access the website"
$entraWebUiStaffApName = "$prefix-Frontend-Staff$suffix"
$entraWebUiStaffApNote = "This application enables staff to authenticate and access the website"
$functionAppPrivateName = "$prefix-dev-prv-fn$suffix"
$functionAppPublicName = "$prefix-dev-pub-fn$suffix"
$functionAppStorageAccountName = "${brand}devfnconsumptionsto"
$keyVaultName = "$prefix-dev-kv$suffix"
$location = "westus3"
$mapLocation = "westcentralus"
$mapName = "$prefix-dev-map$suffix"
$privateStorageAccountName = "${brand}devmainstoprv"
$publicStorageAccountName = "${brand}devmainstopub"
$redisName = "$prefix-dev-redis$suffix"
$resourceGroupName = "$prefix-dev-rg$suffix"

# The web app that consumes the resources deployed by this script is configured to use SQL Azure Elastic Scale. 
# As a result, the SQL scripts deploy a routing database that directs users to the appropriate shard database or databases. 
# This parameter specifies the name of the shard database(s).
$SqlShardNumbers = @(1, 61)

function Deploy-Infrastructure {
    param (
        [char]$keyVaultRestoreOptions, # "P" for purge, "R" for restore
        [string]$apimPrivateApiDisplayName,
        [string]$apimPrivateApiName,
        [string]$apimPublicApiDisplayName,
        [string]$apimPublicApiName,
        [string]$apimPublisherEmail,
        [string]$apimPublisherName,    
        [string]$apimServiceName,    
        [string]$appInsightsResourceName,
        [string]$appServicenName,        
        [string]$appServicePlanName,
        [string]$authClientId,
        [string]$authClientSecret,
        [string]$brand,
        [string]$CosmosAccount,   
        [string]$CosmosDataBase,
        [string]$DevOpsServiceCnnEntraAppClientId,
        [string]$emailContainerName,
        [string]$EntraAppInsightsApName,
        [string]$EntraAppInsightsApNote,
        [string]$EntraIntegrationApName,
        [string]$EntraIntegrationApNote,  
        [string]$EntraWebUiClientApName,
        [string]$EntraWebUiClientApNote,  
        [string]$EntraWebUiStaffApName,
        [string]$EntraWebUiStaffApNote,          
        [string]$EntraWebUiVendorApName,
        [string]$EntraWebUiVendorApNote,  
        [string]$environment,        
        [string]$functionAppPrivateName,
        [string]$functionAppPublicName,
        [string]$functionAppStorageAccountName,    
        [string]$keyVaultName,
        [string]$location,
        [string]$mapLocation,
        [string]$mapName,
        [string]$privateStorageAccountName,
        [string]$publicStorageAccountName,
        [string]$redisName,
        [string]$resourceGroupName,
        [array]$SqlShardNumbers,
        [string]$tenantId,
        [string]$subscriptionId
    )

    # References a script responsible for locating other script files based on their names.
    . "$PSScriptRoot/../FindFileByName.ps1"

    # Move up one directory
    $parentDir = Split-Path -Path $PSScriptRoot -Parent 
    $rootDir = Split-Path -Path $parentDir -Parent 
    $deployInfrastructureController = Find-FileByName -FileName "DeployInfrastructureController.ps1" -CurrentDirectory $rootDir

    & $deployInfrastructureController `
        -keyVaultRestoreOptions $keyVaultRestoreOptions `
        -ApimPrivateApiDisplayName $apimPrivateApiDisplayName `
        -ApimPrivateApiName $apimPrivateApiName `
        -ApimPrivateSubscriptionName $apimPrivateSubscriptionName `
        -ApimPublicApiDisplayName $apimPublicApiDisplayName `
        -ApimPublicApiName $apimPublicApiName `
        -ApimPublicSubscriptionName $apimPublicSubscriptionName `
        -ApimPublisherEmail $apimPublisherEmail `
        -ApimPublisherName $apimPublisherName `
        -ApimServiceName $apimServiceName `
        -AppInsightsResourceName $appInsightsResourceName `
        -AppserviceName $appserviceName `
        -AppservicePlanName $appservicePlanName `
        -AuthClientId $authClientId `
        -AuthClientSecret $authClientSecret `
        -Brand $brand `
        -CosmosAccount $CosmosAccount `
        -CosmosDataBase $CosmosDataBase `
        -DevOpsServiceCnnEntraAppClientId $DevOpsServiceCnnEntraAppClientId `
        -EntraAppInsightsApName $EntraAppInsightsApName `
        -EntraAppInsightsApNote $EntraAppInsightsApNote `
        -EntraIntegrationApName $EntraIntegrationApName `
        -EntraIntegrationApNote $EntraIntegrationApNote `
        -EntraWebUiClientApName $EntraWebUiClientApName `
        -EntraWebUiClientApNote $EntraWebUiClientApNote `
        -EntraWebUiVendorApName $EntraWebUiVendorApName `
        -EntraWebUiVendorApNote $EntraWebUiVendorApNote `
        -EntraWebUiStaffApName $EntraWebUiStaffApName `
        -EntraWebUiStaffApNote $EntraWebUiStaffApNote `
        -EmailContainerName $emailContainerName `
        -Environment $environment `
        -FunctionAppPrivateName $functionAppPrivateName `
        -FunctionAppPublicName $functionAppPublicName `
        -FunctionAppStorageAccountName $functionAppStorageAccountName `
        -KeyVaultName $keyVaultName `
        -Location $location `
        -MapLocation $mapLocation `
        -MapName $mapName `
        -PrivateStorageAccountName $privateStorageAccountName `
        -PublicStorageAccountName $publicStorageAccountName `
        -RedisName $redisName `
        -ResourceGroupName $resourceGroupName `
        -SqlShardNumbers $SqlShardNumbers `
        -TenantId $tenantId `
        -SubscriptionId $subscriptionId
}

# Deploy to Development
Deploy-Infrastructure `
    -apimPrivateApiDisplayName $apimPrivateApiDisplayName `
    -apimPrivateApiName $apimPrivateApiName `
    -apimPrivateSubscriptionName $apimPrivateSubscriptionName `
    -apimPublicApiDisplayName $apimPublicApiDisplayName `
    -apimPublicApiName $apimPublicApiName `
    -apimPublicSubscriptionName $apimPublicSubscriptionName `
    -apimPublisherEmail $apimPublisherEmail `
    -apimPublisherName $apimPublisherName `
    -apimServiceName $apimServiceName `
    -appInsightsResourceName $appInsightsResourceName `
    -appserviceName $appserviceName `
    -appservicePlanName $appservicePlanName `
    -authClientId $authClientId `
    -authClientSecret $authClientSecret `
    -brand $prefix `
    -CosmosDataBase $CosmosDataBase `
    -CosmosAccount $CosmosAccount `
    -DevOpsServiceCnnEntraAppClientId $DevOpsServiceCnnEntraAppClientId `
    -EntraAppInsightsApName $entraAppInsightsApName `
    -EntraAppInsightsApNote $entraAppInsightsApNote `
    -EntraIntegrationApName $entraIntegrationApName `
    -EntraIntegrationApNote $entraIntegrationApNote `
    -EntraWebUiClientApName $entraWebUiClientApName `
    -EntraWebUiClientApNote $entraWebUiClientApNote `
    -EntraWebUiVendorApName $entraWebUiVendorApName `
    -EntraWebUiVendorApNote $entraWebUiVendorApNote `
    -EntraWebUiStaffApName $entraWebUiStaffApName `
    -EntraWebUiStaffApNote $entraWebUiStaffApNote `
    -emailContainerName $emailContainerName `
    -environment $environment `
    -functionAppPrivateName $functionAppPrivateName `
    -functionAppPublicName $functionAppPublicName `
    -functionAppStorageAccountName $functionAppStorageAccountName `
    -keyVaultName $keyVaultName `
    -keyVaultRestoreOptions $keyVaultRestoreOptions `
    -location $location `
    -mapLocation $mapLocation `
    -mapName $mapName `
    -privateStorageAccountName $privateStorageAccountName `
    -publicStorageAccountName $publicStorageAccountName `
    -redisName $redisName `
    -resourceGroupName $resourceGroupName `
    -SqlShardNumbers $SqlShardNumbers `
    -tenantId $tenantId `
    -subscriptionId $subscriptionId
    
