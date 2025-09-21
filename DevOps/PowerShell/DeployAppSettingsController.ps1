# This script is called by DeployAppSettingsController.ps1 script.
param (
    [bool]$AddSettingsToKeyVault,
    [bool]$IsPublicFnApp, 
    [bool]$IsWebApp,
    [string]$AppServiceName,
    [String]$Environment,
    [string]$KeyVaultName,
    [string]$NetVersion,
    [string]$ResourceGroupName,
    [string]$SlotName
)

# Combine the app settings from the App Service or Function App and the settings from the Excel file.
function Merge-AppSettings {
    param (
        [Parameter(Mandatory)] 
        [array]$appServiceSettings,
        [Parameter(Mandatory)]      
        [hashtable]$excelAppSettings
    )
    $merged = @{}
    foreach ($setting in $appServiceSettings) {
        $merged[$setting.Name] = $setting.Value
    }

    # Settings from the Excel file will override the existing settings.
    foreach ($key in $excelAppSettings.Keys) {
        $merged[$key] = $excelAppSettings[$key]
    }

    return $merged
}

# Save all app settings to a JSON file.
function Save-AppSettingsJson {
    param (
        [hashtable]$mergedSettings
    )

    $jsonPath = "D:\appsettings.json"
    $jsonContent = $mergedSettings | ConvertTo-Json -Depth 10
    Set-Content -Path $jsonPath -Value $jsonContent -Encoding UTF8
    return $jsonPath
}

# Check if the last version of Az.Websites module is installed.
$latestVersion = (Find-Module -Name Az.Websites).Version
$installedVersion = Get-InstalledModule -Name Az.Websites -ErrorAction SilentlyContinue

if ($installedVersion -and $installedVersion.Version -ne $latestVersion) {
    Write-Host "Updating Az.Websites module to the latest version: $latestVersion" -ForegroundColor Yellow
    if ($env:BUILD_BUILDID) {
        Install-Module -Name Az.Websites -Scope CurrentUser -Force
    }
    else {
        Install-Module -Name Az.Websites -Scope AllUsers -Force
    }
}


if (-not (Get-Module -Name Az.Websites)) {
    Write-Host "Importing Az.Websites module" -ForegroundColor Yellow
    Import-Module Az.Websites
}

try {    
    . "$PSScriptRoot/FindFileByName.ps1"	
    $parentDir = Split-Path -Path $PSScriptRoot -Parent 
    $rootDir = Split-Path -Path $parentDir -Parent
    $settingsManager = Find-FileByName -FileName "SettingsManager.ps1" -CurrentDirectory $rootDir | Select-Object -First 1
    . $settingsManager
    $settingsFilePath = Find-FileByName -FileName "SettingsIndex.xlsx" -CurrentDirectory $rootDir | Select-Object -First 1
    $keyVaultSecretsScript = Find-FileByName -FileName "KeyVaultSecrets.ps1" -CurrentDirectory $rootDir | Select-Object -First 1

    if ($AddSettingsToKeyVault) {
        # Add the remaining secrets to the Azure Key Vault.         That is secrets not generated in Azure and Entra secrets.

        # 1 Twilio
        $twilioSecretPath = 'Twilio:AuthToken'

        # 1.1 Get the Twilio auth token from the excel file.
        $twilioTokenSecretName = GetKeyVaultSecretKeyName `
            -Environment $Environment `
            -SettingPath $twilioSecretPath  `
            -ExcelFilePath $settingsFilePath  
    
        # 1.2 Get the Twilio auth token value from the excel file.
        $twilioTokenSecretValue = GetSettingValue `
            -Environment $Environment `
            -SettingPath $twilioSecretPath `
            -ExcelFilePath $settingsFilePath

        # 1.3 Add Twilio auth token to key vault.
        & $keyVaultSecretsScript `
            -keyVaultName $keyVaultName `
            -secretName $twilioTokenSecretName `
            -secretValue $twilioTokenSecretValue

        # 2 Facebook.
        $facebookSecretPath = 'MetaAppCredentials:Facebook:ClientSecret'

        # 2.1 Get the Facebook auth token from the excel file.
        $facebookSecretName = GetKeyVaultSecretKeyName `
            -Environment $Environment `
            -SettingPath $facebookSecretPath `
            -ExcelFilePath $settingsFilePath

        # 2.2 Get the Facebook auth token value from the excel file.
        $facebookTokenSecretValue = GetSettingValue `
            -Environment $Environment `
            -SettingPath $facebookSecretPath `
            -ExcelFilePath $settingsFilePath    

        # 2.3 Add Facebook auth token to key vault.
        & $keyVaultSecretsScript `
            -keyVaultName $keyVaultName `
            -secretName $facebookSecretName `
            -secretValue $facebookTokenSecretValue

        # 3 Instagram.
        $instagramSecretPath = 'MetaAppCredentials:Instagram:ClientSecret'

        # 3.1 Get the Instagram auth token from the excel file.
        $instagramSecretName = GetKeyVaultSecretKeyName `
            -Environment $Environment `
            -SettingPath $instagramSecretPath `
            -ExcelFilePath $settingsFilePath

        # 3.2 Get the Instagram auth token value from the excel file.
        $instagramTokenSecretValue = GetSettingValue `
            -Environment $Environment `
            -SettingPath $instagramSecretPath `
            -ExcelFilePath $settingsFilePath    

        # 3.3 Add Instagram auth token to key vault.
        & $keyVaultSecretsScript `
            -keyVaultName $keyVaultName `
            -secretName $instagramSecretName `
            -secretValue $instagramTokenSecretValue

        # 4 AppInsights SubscriptionId.
        $ainSecretPath = 'Azure:AppInsights:Resources:SubscriptionId'
        
        # 4.1 Get the AppInsights SubscriptionId from the excel file.
        $ainSecretName = GetKeyVaultSecretKeyName `
            -Environment $Environment `
            -SettingPath $ainSecretPath `
            -ExcelFilePath $settingsFilePath

        # 4.2 Get the AppInsights SubscriptionId value from the excel file.
        $ainSecretValue = GetSettingValue `
            -Environment $Environment `
            -SettingPath $ainSecretPath `
            -ExcelFilePath $settingsFilePath

        # 4.3 Add AppInsights SubscriptionId to key vault.
        & $keyVaultSecretsScript `
            -keyVaultName $keyVaultName `
            -secretName $ainSecretName `
            -secretValue $ainSecretValue

        # 5 EntraAppInsightsAppSecret
        $entraAppInsightsAppSecretPath = 'Azure:Entra:AppInsightsApp:Secret'

        # 5.1 Get the Entra App Insights app secret from the excel file.
        $entraAppInsightsAppSecretName = GetKeyVaultSecretKeyName `
            -Environment $Environment `
            -SettingPath $entraAppInsightsAppSecretPath `
            -ExcelFilePath $settingsFilePath

        # 5.2 Get the Entra App Insights app secret value from the excel file.
        $entraAppInsightsAppSecretValue = GetSettingValue `
            -Environment $Environment `
            -SettingPath $entraAppInsightsAppSecretPath `
            -ExcelFilePath $settingsFilePath

        # 5.3 Add Entra App Insights app secret to key vault.
        & $keyVaultSecretsScript `
            -keyVaultName $keyVaultName `
            -secretName $entraAppInsightsAppSecretName `
            -secretValue $entraAppInsightsAppSecretValue
    }

    # Update app service with the existing app settings from the App Service or Function App and sttings from the Excel file.
    # Existing app settings have precedence over the settings in the Excel file.
    Write-host "Deploying app settings" -ForegroundColor Yellow

    # Get the app settings from the Excel file.
    $excelAppSettings = GetAppSettings `
        -IsWebApp $IsWebApp `
        -Environment $Environment `
        -ExcelFilePath $settingsFilePath `
        -KeyVaultName $KeyVaultName 

    if ($IsWebApp) {  
        # Use the app settings from the production slot, since both slots share the same configuration.
        $appServiceSettings = (
            Get-AzWebApp `
                -ResourceGroupName $ResourceGroupName `
                -Name $AppServiceName).SiteConfig.AppSettings
           
        # Merge the app settings from the App Service and the Excel file.
        $mergedSettings = Merge-AppSettings `
            -appServiceSettings $appServiceSettings `
            -excelAppSettings $excelAppSettings

        # Deploy settings to the production slot
        Set-AzWebApp `
            -AppSettings $mergedSettings `
            -Name $AppServiceName `
            -NetFrameworkVersion $NetVersion `
            -ResourceGroupName $ResourceGroupName `
            -Use32BitWorkerProcess $false
 
        # Deploy settings to the non-production slot.
        Set-AzWebAppSlot `
            -AppSettings $mergedSettings `
            -Name $AppServiceName `
            -NetFrameworkVersion $NetVersion `
            -ResourceGroupName $ResourceGroupName `
            -Slot $SlotName `
            -Use32BitWorkerProcess $false       
    }
    else {
        # Az PowerShell's Update-AzFunctionAppSetting does not support the slot parameter, 
        # Meaning Azure CLI must be used for updating function app settings in a specific deployment slot.

        # Use the app settings from the production slot, since both slots share the same configuration.
        $appServiceSettings = az functionapp config appsettings list `
            --resource-group $ResourceGroupName `
            --name $AppServiceName `
            --query "[].{Name:name, Value:value}" `
            --output json | ConvertFrom-Json

        # Merge the app settings from the App Service and the Excel file.
        $mergedSettings = Merge-AppSettings `
            -appServiceSettings $appServiceSettings `
            -excelAppSettings $excelAppSettings   
           
        # Function apps must include an AzureWebJobsStorage setting with a valid storage account connection string.
        if ($IsPublicFnApp) {
            $settingPath = "Azure:StorageAccount:BlobStorage:PublicAccountConnectionString"
        }
        else {
            $settingPath = "Azure:StorageAccount:BlobStorage:PrivateAccountConnectionString"
        }
    
        # Add a new setting to the mergedSettings list.
        # Key = AzureWebJobsStorage and value = key vault reference to the connectiong string.
        $mergedSettings["AzureWebJobsStorage"] = $mergedSettings[$settingPath]
            
        # The settings prameter is a JSON file containing the app settings to be deployed.
        # Don't use key value pairs directly in the command line as it can exceed the maximum command length limit.            
        $jsonSettings = Save-AppSettingsJson -mergedSettings $mergedSettings

        az functionapp config appsettings set `
            --name $AppServiceName `
            --resource-group $ResourceGroupName `
            --settings @$jsonSettings

        az functionapp config appsettings set `
            --name $AppServiceName `
            --resource-group $ResourceGroupName `
            --slot $SlotName `
            --settings @$jsonSettings            

        # Set the .NET Framework version to v9.0 and disable 32-bit worker process for the function app.
        az functionapp config set `
            --name $AppServiceName `
            --resource-group $ResourceGroupName `
            --net-framework-version $NetVersion `
            --use-32bit-worker-process false        
                
        az functionapp config set `
            --name $AppServiceName `
            --resource-group $ResourceGroupName `
            --slot $SlotName `
            --net-framework-version $NetVersion `
            --use-32bit-worker-process false   

        # Set the Always On setting to true for the function app.
        az webapp config set `
            --resource-group $ResourceGroupName `
            --name $AppServiceName `
            --always-on true

        az webapp config set `
            --always-on true `
            --name $AppServiceName `
            --resource-group $ResourceGroupName `
            --slot $SlotName 
    }

    Write-host "App settings deployed" -ForegroundColor Green     
}
catch {
    Write-Host "Failed to process deploy app settings" -ForegroundColor Red
    Write-Host "File DeployAppSettings.ps1, line Number: $($_.InvocationInfo.ScriptLineNumber)"
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host "Stack Trace: $($_.Exception.StackTrace)"
    Exit 1
}