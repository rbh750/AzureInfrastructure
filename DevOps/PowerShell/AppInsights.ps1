# 1 Add the Application Insights instrumentation key to the key vault. This key is referenced by the function apps.
# 2 Save the settings used by the AppInsightsTelemetryService to the Excel file, 
# excluding the Entra app registration credentials used by the AppInsightsQueryService, 
# which are set in the WebAppBicepController.ps1 script.

param (
    [object]$BicepOutputParameters,
    [string]$AppInsightsResourceName,
    [string]$Environment,
    [string]$keyVaultName,    
    [string]$ResourceGroupName,
    [string]$SubscriptionId,
    [string]$TenantId
)

# Dot-source the FindFileByName.ps1 script to include the function
. "$PSScriptRoot/FindFileByName.ps1" 
$settingsManager = Find-FileByName -FileName "SettingsManager.ps1" -CurrentDirectory $rootDir
. $settingsManager
$settingsFilePath = Find-FileByName -FileName "SettingsIndex.xlsx" -CurrentDirectory $rootDir    
$keyVaultSecretsScript = Find-FileByName -FileName "KeyVaultSecrets.ps1" -CurrentDirectory $rootDir

try {

    # Get the instrumentation key anme from the settings file
    $settingPath = "AppInsights-Instrumentation-Key"
    $secretKeyName = GetKeyVaultSecretKeyName `
        -Environment $Environment `
        -SettingPath $settingPath `
        -ExcelFilePath $settingsFilePath    

    # Save instrumentation key to key vault
    & $keyVaultSecretsScript `
        -keyVaultName $keyVaultName `
        -secretName $secretKeyName `
        -secretValue $BicepOutputParameters.applicationInsightsInstrumentationKey.value

    if ($Environment.ToLower() -eq "prod") {
        return
    }

    Write-Host "Adding Application Insights values to settings file" -ForegroundColor Yellow

    SetSettingValue `
        -Environment $Environment `
        -SettingPath "Azure:AppInsights:ClientCredentials:TenantId" `
        -SettingValue $TenantId `
        -ExcelFilePath $settingsFilePath 

    SetSettingValue `
        -Environment $Environment `
        -SettingPath "Azure:AppInsights:ConnectionString" `
        -SettingValue $BicepOutputParameters.applicationInsightsConnectionString.value `
        -ExcelFilePath $settingsFilePath     

    SetSettingValue `
        -Environment $Environment `
        -SettingPath "Azure:AppInsights:Resources:ResourceGroupName" `
        -SettingValue $ResourceGroupName `
        -ExcelFilePath $settingsFilePath     

    SetSettingValue `
        -Environment $Environment `
        -SettingPath "Azure:AppInsights:Resources:ResourceNameApi" `
        -SettingValue $AppInsightsResourceName `
        -ExcelFilePath $settingsFilePath     

    SetSettingValue `
        -Environment $Environment `
        -SettingPath "Azure:AppInsights:Resources:ResourceNameWebJobs" `
        -SettingValue $AppInsightsResourceName `
        -ExcelFilePath $settingsFilePath     
    
    SetSettingValue `
        -Environment $Environment `
        -SettingPath "Azure:AppInsights:Resources:SubscriptionId" `
        -SettingValue $SubscriptionId `
        -ExcelFilePath $settingsFilePath

    Write-Host "Values added to settings file" -ForegroundColor Green        

}
catch {
    Write-Host "Failed to prcess Application Insights" -ForegroundColor Red
    Write-Host "File AppInsights.ps1, line Number: $($_.InvocationInfo.ScriptLineNumber)"
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host "Stack Trace: $($_.Exception.StackTrace)"
}   