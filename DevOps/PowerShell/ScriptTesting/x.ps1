$authClientId = 'b21ca38f-bcc2-4109-853a-c2b47de0633b'
$authClientSecret = 'ePW8Q~imw_bmWf~dKTBSJ5LKdo60iZDBFc5_ycFi'
$tenantId = 'cbc31bc0-a781-4712-809b-3b404c5e19e2'
$subscriptionId = '70147690-87c9-4c3b-9b92-b0470e17a3ab'


# Connect to Azure using a service principal
az login --service-principal -u $authClientId -p $authClientSecret --tenant $tenantId --output none
az account set --subscription $subscriptionId

# $latestVersion = (Find-Module -Name Az.ApiManagement).Version
# $installedVersion = Get-InstalledModule -Name Az.ApiManagement -ErrorAction SilentlyContinue

# if ($installedVersion -and $installedVersion.Version -ne $latestVersion) {
#     Write-Host "Updating Az.ApiManagement module to the latest version: $latestVersion" -ForegroundColor Yellow
#     if ($env:BUILD_BUILDID) {
#         Install-Module -Name Az.ApiManagement -Scope CurrentUser -Force
#     }
#     else {
#         Install-Module -Name Az.ApiManagement -Scope AllUsers -Force
#     }
# }



$ShardNumbers = @(1, 61)
$AdminUser = "sysadmin"
$Brand = "wwtp"
$Environment = "dev"
$KeyVaultName = "wwtp-dev-kv-36"
$ResourceGroupName = "wwtp-dev-rg-36"
$WebUser = "webuser"


$Environment = "dev"
$RedisName = "wwtp-dev-redis-36"
$SubscriptionId = $subscriptionId 



. "$PSScriptRoot/../FindFileByName.ps1"	
$parentDir = Split-Path -Path $PSScriptRoot -Parent 
$rootDir = Split-Path -Path $parentDir -Parent 
$settingsManager = Find-FileByName -FileName "SettingsManager.ps1" -CurrentDirectory $rootDir
. $settingsManager
$settingsFilePath = Find-FileByName -FileName "SettingsIndex.xlsx" -CurrentDirectory $rootDir
$keyVaultSecretsScript = Find-FileByName -FileName "KeyVaultSecrets.ps1" -CurrentDirectory $rootDir
$cosmosScript = Find-FileByName -FileName "CosmosDb.ps1" -CurrentDirectory $rootDir
$deployAppSettingsScript = Find-FileByName -FileName "DeployAppSettings.ps1" -CurrentDirectory $rootDir
$fnAppAuthenticationScript = Find-FileByName -FileName "FnAppAuthentication.ps1" -CurrentDirectory $rootDir
$redisScripthPath = Find-FileByName -FileName "Redis.ps1" -CurrentDirectory $rootDir
$sqlServerScript = Find-FileByName -FileName "SqlServer.ps1" -CurrentDirectory $rootDir


& $sqlServerScript `
    -ShardNumbers $ShardNumbers `
    -AdminUser "sysadmin" `
    -Brand $Brand `
    -Environment $Environment `
    -keyVaultName $KeyVaultName `
    -ResourceGroupName $ResourceGroupName `
    -Webuser "webuser"

# & $redisScripthPath `
#     -Environment $Environment `
#     -KeyVaultName $KeyVaultName `
#     -RedisName $RedisName `
#     -ResourceGroupName $ResourceGroupName `
#     -SubscriptionId $SubscriptionId


# # 3 Add authentication to function apps.
# Write-Host "3 Adding authentication to APIs" -ForegroundColor Yellow    
# $privateFunctionApp = Get-AzFunctionApp -ResourceGroupName $ResourceGroupName -Name $FunctionAppPrivateName -SubscriptionId $SubscriptionId
# $publicFunctionApp = Get-AzFunctionApp -ResourceGroupName $ResourceGroupName -Name $FunctionAppPrivateName -SubscriptionId $SubscriptionId
# $fnAppAuthenticationScript = Find-FileByName -FileName "FnAppAuthentication.ps1" -CurrentDirectory $rootDir

# $ApimServiceName ='wwtp-dev-apim-228'
# $EntraIntegrationApName = 'Wwtp-Backend-Integration-228'
# $ResourceGroupName= 'wwtp-dev-rg-228'
# $FunctionAppPrivateName= 'wwtp-dev-prv-fn-228'

# $appRegistrationName = $EntraIntegrationApName
# $appInfo = az ad app list --display-name $appRegistrationName --query "[0].{appId:appId, objectId:id}" -o json | ConvertFrom-Json
# $clientId = $appInfo.appId
# $objectId = $appInfo.objectId
# $allowedTokenAudiences = "api://$($clientId)"
# $issuerUrl = "https://login.microsoftonline.com/$($TenantId)/v2.0"        

# $d1= az rest --method get `
#   --url "https://management.azure.com/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroupName)/providers/Microsoft.Web/sites/$($FunctionAppPrivateName)?api-version=2024-04-01"

#  $d1  = az rest --method get `
#   --url "https://management.azure.com/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroupName)/providers/Microsoft.Web/sites/$($FunctionAppPrivateName)/config/authsettingsV2?api-version=2024-04-01"

# $jsonText = $d1 | ConvertTo-Json -Depth 10
# Write-Output $jsonText

# # Private function app
# $clientSecretSettingName = 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'
# & $fnAppAuthenticationScript `
#     -AllowedTokenAudiences $allowedTokenAudiences `
#     -ApimServiceName $ApimServiceName `
#     -ClientId $clientId `
#     -ClientSecretSettingName $clientSecretSettingName `
#     -FunctionAppName $FunctionAppPrivateName `
#     -IssuerUrl $issuerUrl `
#     -ObjectId $objectId `
#     -ResourceGroupName $ResourceGroupName `
#     -SubscriptionId $SubscriptionId



# $script = Find-FileByName -FileName "UploadEmailTemplates.ps1" -CurrentDirectory $rootDir    

# & $script `
#     -Brand $Brand `
#     -ContainerName 'email-templates' `
#     -keyVaultName $KeyVaultName `
#     -ResourceGroupName $ResourceGroupName `
#     -StorageAccountName 'wwtpdevmainstopub'

# $bicepFileRedis = Find-FileByName -FileName "Redis.bicep" -CurrentDirectory $rootDir

# az deployment group create `
#     --resource-group $ResourceGroupName `
#     --template-file $bicepFileRedis `
#     --parameters `
#     redisName=$RedisName

# $redisKey = az redis list-keys --resource-group $ResourceGroupName --name $RedisName --query "primaryKey" -o tsv


# # 1 Get the Redis key name form the excel file.
# $settingPath = "Azure:Redis:Key" 
# $secretKeyName = GetKeyVaultSecretKeyName `
#     -Environment $Environment `
#     -SettingPath $settingPath `
#     -ExcelFilePath $settingsFilePath      

# # 2 Save the Redis key value to key vault.
# & $keyVaultSecretsScript `
#     -keyVaultName $KeyVaultName `
#     -secretName $secretKeyName `
#     -secretValue $redisKey

# if ($Environment.ToLower() -ne "prod") {Kellyville Station, Kellyvillerou
#     # 4 Set the PRIVATE connection string and db name in the excel file.
#     SetSettingValue `
#         -Environment $Environment `
#         -SettingPath $settingPath `
#         -SettingValue $redisKey `
#         -ExcelFilePath $settingsFilePath          
# }   

# $path = 'WebApps\WebApp.Wwtp\AzureInfrastructure\PowerShell\DeployAppSettings.ps1'
# $scriptPath = Get-ChildItem -Path "$($path)" -Recurse -Filter "DeployAppSettings.ps1" | Select-Object -ExpandProperty FullName


# $AppserviceName = 'wwtp-dev-web-app-175'


# & $deployAppSettingsScript `
#     -AppServiceName $AppserviceName `
#     -Environment $Environment `
#     -keyVaultName $KeyVaultName `
#     -ResourceGroupName $ResourceGroupName 

# & $appServiceIamScript `
#     -EApClientId "f44835cf-55af-41ea-81fb-7c8cdeb56fe7" `
#     -AppServiceName "wwtp-dev-prv-fn-consumption-153" `
#     -ResourceGroupName "wwtp-dev-rg-153"

# $CosmosAccount = "wwtp-cosmos-server-175"
# $CosmosDataBase = "wwtp-db-175"
# $Environment = "dev"
# $KeyVaultName = "wwtp-dev-kv-175"
# $ResourceGroupName = "wwtp-dev-rg-175"

# & $cosmosScript `
#     -CosmosAccount $CosmosAccount `
#     -CosmosDataBase $CosmosDataBase `
#     -Environment $Environment `
#     -KeyVaultName $KeyVaultName `
#     -ResourceGroupName $ResourceGroupName

# $containersPath = "Azure:CosmosDb:Containers" 
# $containers = GetSettingValue `
#     -Environment $Environment `
#     -SettingPath $containersPath `
#     -ExcelFilePath $settingsFilePath 

# foreach ($c in $containers | ConvertFrom-Json) { 

#     Write-Host "Creating and configuring container $($c.Id)" -ForegroundColor Yellow

#     # Create the container
#     az cosmosdb sql container create `
#         --account-name $CosmosAccount `
#         --database-name $CosmosDataBase `
#         --name $c.Id `
#         --partition-key-path "/$($c.PartitionKey)" `
#         --resource-group $ResourceGroupName `
#         --output none

#     # Enable the TTL if specified but don't set it to a specific value.
#     # TTL is specified at the entity level.
#     if ($null -ne $c.TimeToLive) {
#         az cosmosdb sql container update `
#             --account-name $CosmosAccount `
#             --database-name $CosmosDataBase `
#             --name $c.Id `
#             --resource-group $ResourceGroupName `
#             --ttl -1 `
#             --output none
#     }
# }


# Copy app settings from production slot to staging slot in batches to avoid command length limits

# $resourceGroup = "wwtp-dev-rg-202"
# $appName = "wwtp-dev-web-app-202"
# $stagingSlot = "staging"

# # Get app settings from the production slot
# $prodSettings = az webapp config appsettings list `
#     --resource-group $resourceGroup `
#     --name $appName `
# | ConvertFrom-Json

# # Filter out slot-specific settings (remove this filter if you want all settings)
# $filteredSettings = $prodSettings | Where-Object { $_.slotSetting -eq $false }

# # Prepare settings as an array of "name=value"
# $settingsArray = $filteredSettings | ForEach-Object { "$($_.name)=$($_.value)" }

# # Set batch size (adjust as needed)
# $batchSize = 1

# for ($i = 0; $i -lt $settingsArray.Count; $i += $batchSize) {
#     $batch = $settingsArray[$i..([Math]::Min($i + $batchSize - 1, $settingsArray.Count - 1))]
#     $batchString = $batch -join " "

#     if ($batch.Contains("Twilio")) {
#         $d = 1
#     }

#     Write-Host "$i out of $($settingsArray.Count)" -ForegroundColor Yellow

#     az webapp config appsettings set `
#         --resource-group $resourceGroup `
#         --name $appName `
#         --slot $stagingSlot `
#         --settings $batchString
# }

Write-Output "App settings copied from Production to Staging in batches successfully!"
