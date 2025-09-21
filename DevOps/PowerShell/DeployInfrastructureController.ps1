param (
    [char]$keyVaultRestoreOptions, # 'P' for purge, 'R' for restore 
    [string]$ApimPrivateApiDisplayName,
    [string]$ApimPrivateApiName,
    [string]$ApimPrivateSubscriptionName,   
    [string]$apimPublicApiDisplayName,
    [string]$ApimPublicApiName,
    [string]$ApimPublicSubscriptionName,
    [string]$ApimPublisherEmail,
    [string]$ApimPublisherName,    
    [string]$ApimServiceName,
    [string]$AppInsightsResourceName,
    [string]$AppServiceName,
    [string]$AppServicePlanName,
    [string]$AuthClientId,
    [string]$AuthClientSecret,
    [string]$Brand,
    [string]$CosmosAccount,      
    [string]$CosmosDataBase,
    [string]$DevOpsServiceCnnEntraAppClientId,
    [string]$EmailContainerName,  
    [string]$EntraAppInsightsApName,
    [string]$EntraAppInsightsApNote,   
    [string]$EntraIntegrationApName,
    [string]$EntraIntegrationApNote, 
    [string]$EntraWebUiClientApName,
    [string]$EntraWebUiClientApNote,   
    [string]$EntraWebUiVendorApName,
    [string]$EntraWebUiVendorApNote,
    [string]$EntraWebUiStaffApName,
    [string]$EntraWebUiStaffApNote,  
    [string]$Environment,
    [string]$FunctionAppPrivateName,
    [string]$FunctionAppPublicName,
    [string]$FunctionAppStorageAccountName,    
    [string]$KeyVaultName,
    [string]$Location,
    [string]$MapLocation,
    [string]$MapName,
    [string]$PrivateStorageAccountName,
    [string]$PublicStorageAccountName,    
    [string]$RedisName,    
    [string]$ResourceGroupName,
    [array]$SqlShardNumbers,
    [string]$TenantId,
    [string]$SubscriptionId
)

# Dot-Sourcing (. script.ps1): call functions to execute the script in the current scope.
# Call Operator (& script.ps1): execute scripts with parameters within its own scope and session.

# Azure CLI does not support setting policy in APIM using the API Management module.
# Use Azure PowerShell module instead.

# |----------------|-----------------------------|---------------------------------|-----------------------------------------|
# | Feature        | Invoke-RestMethod           | az rest                         | Microsoft Graph REST API v1.0           |
# |----------------|-----------------------------|---------------------------------|-----------------------------------------|
# | Type           | PowerShell cmdlet           | Azure CLI command               | RESTful web service endpoint            |
# | Purpose        | General HTTP requests       | Custom HTTP requests via CLI    | Access Microsoft 365 and Azure AD data  |
# | Usage          | PowerShell scripts          | Azure automation and scripts    | Direct API access                       |
# | Authentication | Custom methods              | Azure CLI authentication        | OAuth 2.0 / Bearer tokens       	     |
# | Example        | Invoke-RestMethod -Uri $url | az rest --method GET --uri $url | GET https://graph.microsoft.com/v1.0/me |
# |----------------|-----------------------------|---------------------------------|-----------------------------------------|

# Start timing the deployment
$deploymentStartTime = Get-Date

. "$PSScriptRoot/FindFileByName.ps1"
$rootDir = Split-Path -Path $parentDir -Parent 
$apimBicepFile = Find-FileByName -FileName "Apim.bicep" -CurrentDirectory $rootDir
$appServiceIamScript = Find-FileByName -FileName "AppServiceIam.ps1" -CurrentDirectory $rootDir
$bicepFileFnApp = Find-FileByName -FileName "FnApp.bicep" -CurrentDirectory $rootDir
$bicepFileMain = Find-FileByName -FileName "WebAppInfra.bicep" -CurrentDirectory $rootDir 
$cryptographyScripthPath = Find-FileByName -FileName "Cryptography.ps1" -CurrentDirectory $rootDir
$entraScripthPath = Find-FileByName -FileName "AppRegistration.ps1" -CurrentDirectory $rootDir
$keyVaultRbacRolesScript = Find-FileByName -FileName "KeyVaultRbacRoles.ps1" -CurrentDirectory $rootDir
$redisScripthPath = Find-FileByName -FileName "Redis.ps1" -CurrentDirectory $rootDir
$sqlServerScript = Find-FileByName -FileName "SqlServer.ps1" -CurrentDirectory $rootDir

# Check if the last version of Az.Websites module is installed.
$latestVersion = (Find-Module -Name Az).Version
$installedVersion = Get-InstalledModule -Name Az -ErrorAction SilentlyContinue

if ($installedVersion -and $installedVersion.Version -ne $latestVersion) {
    Write-Host "Updating Az module to the latest version: $latestVersion" -ForegroundColor Yellow
    if ($env:BUILD_BUILDID) {
        Install-Module -Name Az -Scope CurrentUser -Force
    }
    else {
        Install-Module -Name Az -Scope AllUsers -Force
    }
}

if (-not (Get-Module -Name Az)) {
    Write-Host "Importing Az module" -ForegroundColor Yellow
    Import-Module Az
}

# 1 Azure login.
# 1.1 Signs you in so we can run Azure CLI commands.
az login --service-principal -u $AuthClientId -p $AuthClientSecret --tenant $TenantId  --output none
az account set --subscription $SubscriptionId

# 1.2 Signs you in so we can run Azure PowerShell cmdlets.
$secureClientSecret = ConvertTo-SecureString -String $AuthClientSecret -AsPlainText -Force
$authCredentials = New-Object System.Management.Automation.PSCredential ($AuthClientId, $secureClientSecret)
Connect-AzAccount -ServicePrincipal -Tenant $TenantId -Subscription $SubscriptionId -Credential $authCredentials

# 2 Create the resource group
az group create --name $ResourceGroupName --location $Location --output none
Write-Host "Successfully created the resource group" -ForegroundColor Green

# 3 Check if the Key Vault exists in a deleted state and either purge or restore it
$deletedVault = az keyvault list-deleted --query "[?name=='$KeyVaultName']" --output tsv

if ($deletedVault) {
    if ($keyVaultRestoreOptions -eq 'P') {
        Write-Host "Key Vault '$KeyVaultName' exists in a deleted state. Purging it..." -ForegroundColor Yellow
        az keyvault purge --name $KeyVaultName
        Write-Host "Purged Key Vault '$KeyVaultName'" -ForegroundColor Green
    }
    elseif ($keyVaultRestoreOptions -eq 'R') {
        Write-Host "Key Vault '$KeyVaultName' exists in a deleted state. Recovering it..." -ForegroundColor Yellow
        az keyvault recover --name $KeyVaultName
        Write-Host "Recovered Key Vault '$KeyVaultName'" -ForegroundColor Green
    }
    else {
        Write-Host "Invalid option for keyVaultRestoreOptions. Please use 'P' for purge or 'R' for restore." -ForegroundColor Red
        exit 1
    }
}

# 4 Deploy the Bicep template and capture the output
Write-Host "Deploying ApplicationInsights, KeyVault and Storage accounts" -ForegroundColor Yellow
try {
    $deploymentOutput = az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file $bicepFileMain `
        --parameters `
        appInsightsName=$AppInsightsResourceName `
        appServiceName=$AppServiceName `
        appServicePlanName=$AppServicePlanName `
        emailContainerName=$EmailContainerName `
        keyVaultName=$KeyVaultName `
        mapLocation=$MapLocation `
        mapName=$MapName `
        privateStorageAccountName=$PrivateStorageAccountName `
        publicStorageAccountName=$PublicStorageAccountName `
        tenantId=$TenantId `
        --query properties.outputs `
        --output json | Out-String  
} 
catch {
    Write-Host "Bicep template deployment failed" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
Write-Host "Deployment completed" -ForegroundColor Green
$bicepOutputParameters = $deploymentOutput | ConvertFrom-Json

Start-Sleep -Seconds 5

# Assign the "Key Vault Secrets User" role to the web app’s managed identity for access to Key Vault secrets.
& $keyVaultRbacRolesScript `
    -KeyVaultName $KeyVaultName `
    -ApplicationClientId $bicepOutputParameters.appServiceClientId.value `
    -AdminContributorRole $false

& $keyVaultRbacRolesScript `
    -KeyVaultName $KeyVaultName `
    -ApplicationClientId $bicepOutputParameters.appServiceSlotClientId.value `
    -AdminContributorRole $false     

# The DevOps service principal Entra App is created in Azure by the admin before running this script and is responsible for its execution.
# Configure RBAC roles for the DevOps service principal to grant access to the key vault.
Write-Host "Setting DevOps service principal RBAC roles" -ForegroundColor Yellow
$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "KeyVaultRbacRoles.ps1"
& $scriptPath `
    -KeyVaultName $KeyVaultName `
    -ApplicationClientId $AuthClientId `
    -AdminContributorRole $true 

Write-Host "Permissions granted" -ForegroundColor Green

# Entra Integration App
& $entraScripthPath `
    -CreateEnterpriseApplication $false `
    -ProcessingBackendApp $true `
    -ResetPermission $false `
    -AppType $null `
    -AuthClientId $AuthClientId `
    -AuthClientSecret $AuthClientSecret `
    -Brand $Brand `
    -EApExcelClientIdSettingPath 'Azure:Entra:IntegrationApp:ClientId' `
    -EApExcelSecretSettingPath 'Azure:Entra:IntegrationApp:Secret' `
    -EApName $EntraIntegrationApName `
    -EApNote $EntraIntegrationApNote `
    -Environment $Environment `
    -KeyVaultName $KeyVaultName `
    -SubscriptionId $SubscriptionId `
    -TenantId $TenantId    

# Entra AppInsights App required by the AppInsightsQueryService
& $entraScripthPath `
    -CreateEnterpriseApplication $false `
    -ProcessingBackendApp $true `
    -ResetPermission $false `
    -AppType $null `
    -AuthClientId $AuthClientId `
    -AuthClientSecret $AuthClientSecret `
    -Brand $Brand `
    -EApExcelClientIdSettingPath 'Azure:Entra:AppInsightsApp:ClientId' `
    -EApExcelSecretSettingPath 'Azure:Entra:AppInsightsApp:Secret' `
    -EApName $EntraAppInsightsApName `
    -EApNote $EntraAppInsightsApNote `
    -Environment $Environment `
    -KeyVaultName $KeyVaultName `
    -SubscriptionId $SubscriptionId `
    -TenantId $TenantId      

# Entra Web UI Client App
& $entraScripthPath `
    -CreateEnterpriseApplication $false `
    -ProcessingBackendApp $true `
    -ResetPermission $false `
    -AppType 'webUiClient' `
    -AuthClientId $AuthClientId `
    -AuthClientSecret $AuthClientSecret `
    -Brand $Brand `
    -EApExcelClientIdSettingPath 'Azure:Entra:WebUiClientApp:ClientId' `
    -EApExcelSecretSettingPath 'Azure:Entra:WebUiClientApp:Secret' `
    -EApName $EntraWebUiClientApName `
    -EApNote $EntraWebUiClientApNote `
    -Environment $Environment `
    -KeyVaultName $KeyVaultName `
    -SubscriptionId $SubscriptionId `
    -TenantId $TenantId        

# Entra Web UI Vendor App
& $entraScripthPath `
    -CreateEnterpriseApplication $false `
    -ProcessingBackendApp $true `
    -ResetPermission $false `
    -AppType 'webUiVendor' `
    -AuthClientId $AuthClientId `
    -AuthClientSecret $AuthClientSecret `
    -Brand $Brand `
    -EApExcelClientIdSettingPath 'Azure:Entra:WebUiVendorApp:ClientId' `
    -EApExcelSecretSettingPath 'Azure:Entra:WebUiVendorApp:Secret' `
    -EApName $EntraWebUiVendorApName `
    -EApNote $EntraWebUiVendorApNote `
    -Environment $Environment `
    -KeyVaultName $KeyVaultName `
    -SubscriptionId $SubscriptionId `
    -TenantId $TenantId      

# Entra Web UI Staff App
& $entraScripthPath `
    -CreateEnterpriseApplication $true `
    -ProcessingBackendApp $true `
    -ResetPermission $false `
    -AppType 'webUiStaff' `
    -AuthClientId $AuthClientId `
    -AuthClientSecret $AuthClientSecret `
    -Brand $Brand `
    -EApExcelClientIdSettingPath 'Azure:Entra:WebUiStaffApp:ClientId' `
    -EApExcelSecretSettingPath 'Azure:Entra:WebUiStaffApp:Secret' `
    -EApName $EntraWebUiStaffApName `
    -EApNote $EntraWebUiStaffApNote `
    -Environment $Environment `
    -KeyVaultName $KeyVaultName `
    -SubscriptionId $SubscriptionId `
    -TenantId $TenantId 

# Cryptography: create AES and RSA keys, store them in Key Vault, and update the settings file.
& $cryptographyScripthPath `
    -Environment $Environment `
    -KeyVaultName $KeyVaultName 

# Adds the Application Insights instrumentation key to the Key Vault, where it can be accessed by the AppInsightsQueryService.
# This service is used to read the Application Insights logs.
# See the https://github.com/rbh750/Azure for the implementation details of this service.
$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "AppInsights.ps1"
& $scriptPath `
    -BicepOutputParameters $bicepOutputParameters `
    -AppInsightsResourceName $AppInsightsResourceName `
    -Environment $Environment `
    -keyVaultName $KeyVaultName `
    -ResourceGroupName $ResourceGroupName `
    -SubscriptionId $SubscriptionId `
    -TenantId $TenantId    

# Storage accounts
$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Storage.ps1"
& $scriptPath `
    -BicepOutputParameters $bicepOutputParameters `
    -Environment $Environment `
    -ResourceGroupName $ResourceGroupName `
    -StorageAccountName $PrivateStorageAccountName `

# Map
$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Map.ps1"
& $scriptPath `
    -BicepOutputParameters $bicepOutputParameters `
    -Environment $Environment `
    -ResourceGroupName $ResourceGroupName `
    -MapName $MapName `

# Cosmos DB
$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "CosmosDb.ps1"
& $scriptPath `
    -CosmosAccount $cosmosAccount `
    -CosmosDataBase $cosmosDataBase `
    -Environment $Environment `
    -KeyVaultName $KeyVaultName `
    -ResourceGroupName $ResourceGroupName    

# Apis and APIM 
$fnAppScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "FnApp.ps1"
& $fnAppScriptPath `
    -BicepOutputParameters $bicepOutputParameters `
    -ApimBicepFile $apimBicepFile `
    -ApimPrivateApiDisplayName $ApimPrivateApiDisplayName `
    -ApimPrivateApiName $ApimPrivateApiName `
    -ApimPrivateSubscriptionName $ApimPrivateSubscriptionName `
    -ApimPublicApiDisplayName $ApimPublicApiDisplayName `
    -ApimPublicApiName $ApimPublicApiName `
    -ApimPublicSubscriptionName $ApimPublicSubscriptionName `
    -ApimPublisherEmail $ApimPublisherEmail `
    -ApimPublisherName $ApimPublisherName `
    -ApimServiceName $ApimServiceName `
    -Brand $Brand `
    -EntraIntegrationApName $EntraIntegrationApName `
    -Environment $Environment `
    -FunctionAppBicepFile $bicepFileFnApp `
    -FunctionAppPrivateName $FunctionAppPrivateName `
    -FunctionAppPublicName $FunctionAppPublicName `
    -FunctionAppStorageAccountName $FunctionAppStorageAccountName `
    -KeyVaultName $KeyVaultName `
    -ResourceGroupName $ResourceGroupName `
    -SubscriptionId $SubscriptionId `
    -TenantId $TenantId

# Add permissions to deploy, manage, and modify the App Service to the the service connection app registration.
# This allows the DevOps pipelines to deploy the web app to the App Service.
& $appServiceIamScript `
    -EApClientId $DevOpsServiceCnnEntraAppClientId `
    -AppServiceName $AppServiceName `
    -ResourceGroupName $ResourceGroupName

& $appServiceIamScript `
    -EApClientId $DevOpsServiceCnnEntraAppClientId `
    -AppServiceName $FunctionAppPrivateName `
    -ResourceGroupName $ResourceGroupName
    
& $appServiceIamScript `
    -EApClientId $DevOpsServiceCnnEntraAppClientId `
    -AppServiceName $FunctionAppPublicName `
    -ResourceGroupName $ResourceGroupName        

# Sql Server
& $sqlServerScript `
    -ShardNumbers $ShardNumbers `
    -AdminUser "sysadmin" `
    -Brand $Brand `
    -Environment $Environment `
    -keyVaultName $KeyVaultName `
    -ResourceGroupName $ResourceGroupName `
    -Webuser "webuser"

# Uncomment this block if you want to deploy a Redis cache. The deployment typically takes about 30 minutes to complete.
# # Redis
# & $redisScripthPath `
#     -Environment $Environment `
#     -KeyVaultName $KeyVaultName `
#     -RedisName $RedisName `
#     -ResourceGroupName $ResourceGroupName `
#     -SubscriptionId $SubscriptionId

# Calculate and display total deployment time
$deploymentEndTime = Get-Date
$totalElapsedTime = $deploymentEndTime - $deploymentStartTime
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "SCRIPT FINALIZED" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Start time: $($deploymentStartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
Write-Host "End time: $($deploymentEndTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
Write-Host "Total elapsed time: $($totalElapsedTime.Hours) hours, $($totalElapsedTime.Minutes) minutes, $($totalElapsedTime.Seconds) seconds" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Green