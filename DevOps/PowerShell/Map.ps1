param (
    [object]$BicepOutputParameters,
    [string]$Environment,
    [string]$ResourceGroupName,
    [string]$MapName
)

# Dot-source the FindFileByName.ps1 script to include the function
. "$PSScriptRoot/FindFileByName.ps1" 

try {
    Write-Host "Adding map key to key vault" -ForegroundColor Yellow
    $keyVaultSecretsScript = Find-FileByName -FileName "KeyVaultSecrets.ps1" -CurrentDirectory $rootDir
    $settingsManager = Find-FileByName -FileName "SettingsManager.ps1" -CurrentDirectory $rootDir
    . $settingsManager
    $settingsFilePath = Find-FileByName -FileName "SettingsIndex.xlsx" -CurrentDirectory $rootDir    

    # 1 Get the PRIVATE connection string name form the excel file.
    $settingPath = "Azure:Maps:Key"
    $secretKeyName = GetKeyVaultSecretKeyName `
        -Environment $Environment `
        -SettingPath $settingPath `
        -ExcelFilePath $settingsFilePath    

    # 2 Get the PRIVATE connection string value.
    $mapKey = $BicepOutputParameters.azureMapPrimaryKey.value

    # 3 Save the PRIVATE connection string value to key vault
    & $keyVaultSecretsScript `
        -keyVaultName $BicepOutputParameters.keyVaultName.value `
        -secretName $secretKeyName `
        -secretValue $mapKey

    # 4 Set the PRIVATE connection string value in the excel file.
    SetSettingValue `
        -Environment $Environment `
        -SettingPath $settingPath `
        -SettingValue $mapKey `
        -ExcelFilePath $settingsFilePath         

    Write-Host "Values added to settings file" -ForegroundColor Green               
}
catch {
    Write-Host "Failed to add map key to key vault" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}    


