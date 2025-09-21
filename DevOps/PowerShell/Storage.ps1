param (
    [object]$BicepOutputParameters,
    [string]$Environment,
    [string]$ResourceGroupName,
    [string]$StorageAccountName
)

# Dot-source the FindFileByName.ps1 script to include the function
. "$PSScriptRoot/FindFileByName.ps1" 

try {
    Write-Host "Adding storage connection strings to key vault" -ForegroundColor Yellow
    $keyVaultSecretsScript = Find-FileByName -FileName "KeyVaultSecrets.ps1" -CurrentDirectory $rootDir
    $settingsManager = Find-FileByName -FileName "SettingsManager.ps1" -CurrentDirectory $rootDir
    . $settingsManager
    $settingsFilePath = Find-FileByName -FileName "SettingsIndex.xlsx" -CurrentDirectory $rootDir    

    # 1 Get the PRIVATE connection string name form the excel file.
    $settingPath = "Azure:StorageAccount:BlobStorage:PrivateAccountConnectionString"
    $secretKeyName = GetKeyVaultSecretKeyName `
        -Environment $Environment `
        -SettingPath $settingPath `
        -ExcelFilePath $settingsFilePath    

    # 2 Get the PRIVATE connection string value.
    $privateConnectionString = az storage account show-connection-string `
        --name $BicepOutputParameters.privateStorageAccountName.value `
        --resource-group $ResourceGroupName `
        --query connectionString `
        --output tsv

    # 3 Save the PRIVATE connection string value to key vault
    & $keyVaultSecretsScript `
        -keyVaultName $BicepOutputParameters.keyVaultName.value `
        -secretName $secretKeyName `
        -secretValue $privateConnectionString

    # 4 Set the PRIVATE connection string value in the excel file.
    SetSettingValue `
        -Environment $Environment `
        -SettingPath $settingPath `
        -SettingValue $privateConnectionString `
        -ExcelFilePath $settingsFilePath 
       

    # 1 Get the PUBLIC connection string name form the excel file.
    $settingPath = "Azure:StorageAccount:BlobStorage:PublicAccountConnectionString"
    $secretKeyName = GetKeyVaultSecretKeyName `
        -Environment $Environment `
        -SettingPath $settingPath `
        -ExcelFilePath $settingsFilePath    

    # 2 Get the PUBLIC connection string value.
    $publicConnectionString = az storage account show-connection-string `
        --name $BicepOutputParameters.publicStorageAccountName.value `
        --resource-group $ResourceGroupName `
        --query connectionString `
        --output tsv        

    # 3 Save the PUBLIC connection string value to key vault
    & $keyVaultSecretsScript `
        -keyVaultName $BicepOutputParameters.keyVaultName.value `
        -secretName $secretKeyName `
        -secretValue $publicConnectionString

    # 4 Set the PUBLIC connection string value in the excel file.
    SetSettingValue `
        -Environment $Environment `
        -SettingPath $settingPath `
        -SettingValue $publicConnectionString `
        -ExcelFilePath $settingsFilePath     

    Write-Host "Values added to settings file" -ForegroundColor Green               
      
}
catch {
    Write-Host "Failed to add storage account connection strings to key vault" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}    

try {
    Write-Host "Adding tables" -ForegroundColor Yellow

    $storageAccountKey = (
        az storage account keys list `
            --resource-group $ResourceGroupName `
            --account-name $StorageAccountName `
            --query '[0].value' `
            --output tsv
    )

    $tableNames = @(
        'Coupons',
        'FacebookInvalidTokens',
        'FacebookMedia',
        'FacebookTokens',
        'InstagramInvalidTokens',
        'InstagramMedia',
        'InstagramTokens',
        'Otp',
        'RemainderAuth'
    )

    foreach ($tableName in $tableNames) {
        az storage table create --name $tableName --account-name $StorageAccountName --account-key $storageAccountKey
    }

    Write-Host "Tables added" -ForegroundColor Green
}
catch {
    Write-Host "Failed to process storage account." -ForegroundColor Red
    Write-Host "File Storage.ps1, line Number: $($_.InvocationInfo.ScriptLineNumber)"
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host "Stack Trace: $($_.Exception.StackTrace)"
}
