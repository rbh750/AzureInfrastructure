param (
    [string]$CosmosAccount,
    [string]$CosmosDataBase,
    [string]$Environment,
    [string]$KeyVaultName,    
    [string]$ResourceGroupName
)

# Dot-source the FindFileByName.ps1 script to include the function
. "$PSScriptRoot/FindFileByName.ps1" 

Write-Host "Deploying Cosmos DB" -ForegroundColor Yellow

try {
    $cosmosDbBicepFile = Find-FileByName -FileName "CosmosDb.bicep" -CurrentDirectory $rootDir
    $keyVaultSecretsScript = Find-FileByName -FileName "KeyVaultSecrets.ps1" -CurrentDirectory $rootDir
    $settingsManager = Find-FileByName -FileName "SettingsManager.ps1" -CurrentDirectory $rootDir
    . $settingsManager
    $settingsFilePath = Find-FileByName -FileName "SettingsIndex.xlsx" -CurrentDirectory $rootDir        

    $deploymentOutput = az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file $cosmosDbBicepFile `
        --parameters `
        cosmosAccount=$CosmosAccount `
        cosmosDatabase=$CosmosDataBase `
        --query properties.outputs `
        --output json | Out-String

    $bicepOutputParameters = $deploymentOutput | ConvertFrom-Json

    # Add and configure the containers from the excel file.
    $containersPath = "Azure:CosmosDb:Containers" 
    $containers = GetSettingValue `
        -Environment $Environment `
        -SettingPath $containersPath `
        -ExcelFilePath $settingsFilePath 

    foreach ($c in $containers | ConvertFrom-Json) { 
        Write-Host "Creating and configuring container $($c.Id)" -ForegroundColor Yellow

        # Create the container
        az cosmosdb sql container create `
            --account-name $CosmosAccount `
            --database-name $CosmosDataBase `
            --name $c.Id `
            --partition-key-path "/$($c.PartitionKey)" `
            --resource-group $ResourceGroupName `
            --output none

        # Enable the TTL if specified but don't set it to a specific value.
        # TTL is specified at the entity level.
        if ($null -ne $c.TimeToLive) {
            az cosmosdb sql container update `
                --account-name $CosmosAccount `
                --database-name $CosmosDataBase `
                --name $c.Id `
                --resource-group $ResourceGroupName `
                --ttl -1 `
                --output none
        }
    }    

    # 1 Get the PRIVATE connection string name form the excel file.
    $settingPath = "Azure:CosmosDb:ConnectionString" 
    $secretKeyName = GetKeyVaultSecretKeyName `
        -Environment $Environment `
        -SettingPath $settingPath `
        -ExcelFilePath $settingsFilePath      
        
    # 2 Get the PRIVATE connection string value.
    $cnnString = $bicepOutputParameters.cosmosDbConnectionString.value

    # 3 Save the PRIVATE connection string value to key vault
    & $keyVaultSecretsScript `
        -keyVaultName $KeyVaultName `
        -secretName $secretKeyName `
        -secretValue $cnnString

    # 4 Set the PRIVATE connection string and db name in the excel file.
    SetSettingValue `
        -Environment $Environment `
        -SettingPath $settingPath `
        -SettingValue $cnnString `
        -ExcelFilePath $settingsFilePath 

    SetSettingValue `
        -Environment $Environment `
        -SettingPath 'Azure:CosmosDb:DatabaseName' `
        -SettingValue $CosmosDataBase `
        -ExcelFilePath $settingsFilePath             
    
    
    Write-Host "Cosmos DB deployed" -ForegroundColor Green
}
catch {
    Write-Host "Failed to process Cosmos DB" -ForegroundColor Red
    Write-Host "File CosmosDb.ps1, line Number: $($_.InvocationInfo.ScriptLineNumber)"
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host "Stack Trace: $($_.Exception.StackTrace)"
    Exit 1
}