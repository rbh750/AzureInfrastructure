param (
    [string]$Environment,
    [string]$KeyVaultName,    
    [string]$RedisName,
    [string]$ResourceGroupName,
    [string]$SubscriptionId
)

try {
    . "$PSScriptRoot/FindFileByName.ps1" 
    $parentDir = Split-Path -Path $PSScriptRoot -Parent 
    $rootDir = Split-Path -Path $parentDir -Parent 
    $settingsManager = Find-FileByName -FileName "SettingsManager.ps1" -CurrentDirectory $rootDir
    . $settingsManager
    $settingsFilePath = Find-FileByName -FileName "SettingsIndex.xlsx" -CurrentDirectory $rootDir
    $keyVaultSecretsScript = Find-FileByName -FileName "KeyVaultSecrets.ps1" -CurrentDirectory $rootDir
    $bicepFileRedis = Find-FileByName -FileName "Redis.bicep" -CurrentDirectory $rootDir

    # Deploy Redis instance.
    Write-Host "Deploying Redis Cache please wait..." -ForegroundColor Yellow
    az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file $bicepFileRedis `
        --parameters `
        redisName=$RedisName

    # Retrieve the Redis key.
    $redisKey = az redis list-keys --resource-group $ResourceGroupName --name $RedisName --query "primaryKey" -o tsv

    # 1 Get the Redis key name form the excel file.
    $settingPath = "Azure:Redis:Key" 
    $secretKeyName = GetKeyVaultSecretKeyName `
        -Environment $Environment `
        -SettingPath $settingPath `
        -ExcelFilePath $settingsFilePath      

    # 2 Save the Redis key value to key vault.
    & $keyVaultSecretsScript `
        -keyVaultName $KeyVaultName `
        -secretName $secretKeyName `
        -secretValue $redisKey

    # 3 Set Redis key in the excel file.
    SetSettingValue `
        -Environment $Environment `
        -SettingPath $settingPath `
        -SettingValue $redisKey `
        -ExcelFilePath $settingsFilePath          
    
    Write-Host "Redis Cache deployed" -ForegroundColor Green
}
catch {
    Write-Host "Failed to process Redis Cache" -ForegroundColor Red
    Write-Host "File Redis.ps1, line Number: $($_.InvocationInfo.ScriptLineNumber)"
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host "Stack Trace: $($_.Exception.StackTrace)"
    Exit 1
}