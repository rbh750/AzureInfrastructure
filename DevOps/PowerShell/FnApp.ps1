param (
    [object]$BicepOutputParameters,
    [string]$ApimBicepFile,
    [string]$ApimPrivateApiDisplayName,
    [string]$ApimPrivateApiName,
    [string]$ApimPrivateSubscriptionName,   
    [string]$ApimPublicApiDisplayName,
    [string]$ApimPublicApiName,
    [string]$ApimPublicSubscriptionName,
    [string]$ApimPublisherEmail,
    [string]$ApimPublisherName,    
    [string]$ApimServiceName,
    [string]$Brand, 
    [string]$EntraIntegrationApName,
    [string]$Environment,
    [string]$FunctionAppBicepFile,
    [string]$FunctionAppHostingPlanName,
    [string]$FunctionAppPrivateName,
    [string]$FunctionAppPublicName,
    [string]$FunctionAppStorageAccountName,
    [string]$KeyVaultName,
    [string]$ResourceGroupName,
    [string]$SubscriptionId,
    [string]$TenantId
)

function Get-ApimPolicyContent {
    param (
        [string]$filePath
    )
    if (Test-Path $filePath) {
        # Read the content as a raw string
        $content = Get-Content -Path $filePath -Raw
        return $content
    }
    else {
        Write-Host "APIM policy file not found: $filePath" -ForegroundColor Red
        Exit 1
    }
}

function SetCorsPolicy {
    param (
        [string]$Environment,
        [string]$apimPolicyContent,
        [string]$originsReplacementString
    )

    if ($Environment.ToLower() -eq "prod") {
        $apimPolicyContent = $apimPolicyContent -replace '<<origins>>', $originsReplacementString
    }
    else {
        # Remove the cors policy
        $regex = '<cors.*?</cors>'
        $apimPolicyContent = [regex]::Replace($apimPolicyContent, $regex, '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    }

    return $apimPolicyContent
}

# Check if the last version of Az.Websites module is installed.
$latestVersion = (Find-Module -Name Az.ApiManagement).Version
$installedVersion = Get-InstalledModule -Name Az.ApiManagement -ErrorAction SilentlyContinue

if ($installedVersion -and $installedVersion.Version -ne $latestVersion) {
    Write-Host "Updating Az.ApiManagement module to the latest version: $latestVersion" -ForegroundColor Yellow
    if ($env:BUILD_BUILDID) {
        Install-Module -Name Az.ApiManagement -Scope CurrentUser -Force
    }
    else {
        Install-Module -Name Az.ApiManagement -Scope AllUsers -Force
    }
}

. "$PSScriptRoot/FindFileByName.ps1" 
$settingsManager = Find-FileByName -FileName "SettingsManager.ps1" -CurrentDirectory $rootDir
. $settingsManager
$settingsFilePath = Find-FileByName -FileName "SettingsIndex.xlsx" -CurrentDirectory $rootDir       
$apimNamedValuesScript = Find-FileByName -FileName "ApimNamedValues.ps1" -CurrentDirectory $rootDir
$keyVaultRbacRolesScript = Find-FileByName -FileName "KeyVaultRbacRoles.ps1" -CurrentDirectory $rootDir

try {
    # 1 Deploy APIs 
    Write-Host "1 Deploying APIs" -ForegroundColor Yellow
    $fnDeploymentOutput = az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file $FunctionAppBicepFile `
        --parameters `
        appServicePlanId="$($BicepOutputParameters.appServicePlanId.value)" `
        privateFunctionAppName=$FunctionAppPrivateName `
        publicFunctionAppName=$FunctionAppPublicName `
        storageAccountName=$FunctionAppStorageAccountName `
        --query properties.outputs `
        --output json | Out-String
        
    $fnJsonOutput = $fnDeploymentOutput | ConvertFrom-Json     
    
    # Assign the "Key Vault Secrets User" role to the web private fnction’s managed identity for access to Key Vault secrets.
    & $keyVaultRbacRolesScript `
        -KeyVaultName $KeyVaultName `
        -ApplicationClientId $fnJsonOutput.privateFunctionAppClientId.value `
        -AdminContributorRole $false    

    # Assign the "Key Vault Secrets User" role to the web public fnction’s managed identity for access to Key Vault secrets.        
    & $keyVaultRbacRolesScript `
        -KeyVaultName $KeyVaultName `
        -ApplicationClientId $fnJsonOutput.publicFunctionAppClientId.value `
        -AdminContributorRole $false            

    Write-Host "1 APIs deployed" -ForegroundColor Green

    # 2 Deploy APIM
    Write-Host "5 Deploying APIM" -ForegroundColor Yellow
    $apimPrivateSubscriptionPrimaryKey = [System.Guid]::NewGuid().ToString("N")
    $apimPrivateSubscriptionSecondaryKey = [System.Guid]::NewGuid().ToString("N")
    $apimPublicSubscriptionPrimaryKey = [System.Guid]::NewGuid().ToString("N")
    $apimPublicSubscriptionSecondaryKey = [System.Guid]::NewGuid().ToString("N")    

    az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file $ApimBicepFile `
        --parameters `
        apimServiceName=$ApimServiceName `
        privateApiDisplayName=$ApimPrivateApiDisplayName `
        privateApiName=$ApimPrivateApiName `
        publicApiDisplayName=$ApimPublicApiDisplayName `
        publicApiName=$ApimPublicApiName `
        publisherEmail=$ApimPublisherEmail `
        publisherName=$ApimPublisherName `
        privateSubscriptionName=$ApimPrivateSubscriptionName `
        publicSubscriptionName=$ApimPublicSubscriptionName `
        privateSubscriptionPrimaryKey=$apimPrivateSubscriptionPrimaryKey `
        privateSubscriptionSecondaryKey=$apimPrivateSubscriptionSecondaryKey `
        publicSubscriptionPrimaryKey=$apimPublicSubscriptionPrimaryKey `
        publicSubscriptionSecondaryKey=$apimPublicSubscriptionSecondaryKey

    Write-Host "2 APIM deployed" -ForegroundColor Green          

    # 3 Add authentication to function apps.
    Write-Host "3 Adding authentication to APIs" -ForegroundColor Yellow    
    $privateFunctionApp = Get-AzFunctionApp -ResourceGroupName $ResourceGroupName -Name $FunctionAppPrivateName -SubscriptionId $SubscriptionId
    $publicFunctionApp = Get-AzFunctionApp -ResourceGroupName $ResourceGroupName -Name $FunctionAppPrivateName -SubscriptionId $SubscriptionId
    $fnAppAuthenticationScript = Find-FileByName -FileName "FnAppAuthentication.ps1" -CurrentDirectory $rootDir

    $appRegistrationName = $EntraIntegrationApName
    $appInfo = az ad app list --display-name $appRegistrationName --query "[0].{appId:appId, objectId:id}" -o json | ConvertFrom-Json
    $clientId = $appInfo.appId
    $objectId = $appInfo.objectId
    $allowedTokenAudiences = "api://$($clientId)"
    $issuerUrl = "https://login.microsoftonline.com/$($TenantId)/v2.0"        

    # Private function app
    $clientSecretSettingName = 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'
    & $fnAppAuthenticationScript `
        -AllowedTokenAudiences $allowedTokenAudiences `
        -ApimServiceName $ApimServiceName `
        -ClientId $clientId `
        -ClientSecretSettingName $clientSecretSettingName `
        -FunctionAppName $FunctionAppPrivateName `
        -IssuerUrl $issuerUrl `
        -ObjectId $objectId `
        -ResourceGroupName $ResourceGroupName `
        -SubscriptionId $SubscriptionId

    # Private slot
    & $fnAppAuthenticationScript `
        -AllowedTokenAudiences $allowedTokenAudiences `
        -ApimServiceName $ApimServiceName `
        -ClientId $clientId `
        -ClientSecretSettingName $clientSecretSettingName `
        -FunctionAppName $FunctionAppPrivateName `
        -IssuerUrl $issuerUrl `
        -ObjectId $objectId `
        -ResourceGroupName $ResourceGroupName `
        -SubscriptionId $SubscriptionId `
        -Slot "staging"

    # Public function app
    & $fnAppAuthenticationScript `
        -AllowedTokenAudiences $allowedTokenAudiences `
        -ApimServiceName $ApimServiceName `
        -ClientId $clientId `
        -ClientSecretSettingName $clientSecretSettingName `
        -FunctionAppName $FunctionAppPublicName `
        -IssuerUrl $issuerUrl `
        -ObjectId $objectId `
        -ResourceGroupName $ResourceGroupName `
        -SubscriptionId $SubscriptionId
        
    # Public slot
    & $fnAppAuthenticationScript `
        -AllowedTokenAudiences $allowedTokenAudiences `
        -ApimServiceName $ApimServiceName `
        -ClientId $clientId `
        -ClientSecretSettingName $clientSecretSettingName `
        -FunctionAppName $FunctionAppPublicName `
        -IssuerUrl $issuerUrl `
        -ObjectId $objectId `
        -ResourceGroupName $ResourceGroupName `
        -SubscriptionId $SubscriptionId `
        -Slot "staging"

    Write-Host "3 Authentication added to APIs" -ForegroundColor Green    

    # 4 Set RBAC roles for the function apps and slots in Key Vault.
    # Parse the deployment output to get the function app's managed identity principal ID
    Write-Host "4 Setting RBCA roles in Key valut" -ForegroundColor Yellow
    $functionPrivateAppId = $fnJsonOutput.privateFunctionAppId.value
    $functionPublicAppId = $fnJsonOutput.publicFunctionAppId.value
    $functionPrivateAppSlotId = $fnJsonOutput.privateStagingSlotId.value
    $functionPublicAppSlotId = $fnJsonOutput.publicStagingSlotId.value

    $functionAppPrivatePrincipalId = az webapp show --ids $functionPrivateAppId --query identity.principalId --output tsv
    $functionAppPublicPrincipalId = az webapp show --ids $functionPublicAppId --query identity.principalId --output tsv
    $functionAppPrivateSlotPrincipalId = az webapp show --ids $functionPrivateAppSlotId --slot staging --query identity.principalId --output tsv
    $functionAppPublicSlotPrincipalId = az webapp show --ids $functionPublicAppSlotId --slot staging --query identity.principalId --output tsv

    # The Principal ID can also be retrieved using the az webapp identity show command
    # $functionAppPrivateSlotPrincipalId = az webapp identity show `
    #     --name $FunctionAppPrivateName `
    #     --resource-group $ResourceGroupName `
    #     --slot staging `
    #     --query principalId `
    #     --output tsv
    
    # Assign permissions to the function app's managed identity to access the Key Vault
    $keyVaultId = az keyvault show --name $KeyVaultName --resource-group $ResourceGroupName --query id --output tsv
    az role assignment create --role "Key Vault Secrets User" --assignee $functionAppPrivatePrincipalId --scope $keyVaultId
    az role assignment create --role "Key Vault Crypto User" --assignee $functionAppPrivatePrincipalId --scope $keyVaultId
    az role assignment create --role "Key Vault Secrets User" --assignee $functionAppPublicPrincipalId --scope $keyVaultId
    az role assignment create --role "Key Vault Crypto User" --assignee $functionAppPublicPrincipalId --scope $keyVaultId

    az role assignment create --role "Key Vault Secrets User" --assignee $functionAppPrivateSlotPrincipalId --scope $keyVaultId
    az role assignment create --role "Key Vault Crypto User" --assignee $functionAppPrivateSlotPrincipalId --scope $keyVaultId
    az role assignment create --role "Key Vault Secrets User" --assignee $functionAppPublicSlotPrincipalId --scope $keyVaultId
    az role assignment create --role "Key Vault Crypto User" --assignee $functionAppPublicSlotPrincipalId --scope $keyVaultId
    Write-Host "4 Permissions granted" -ForegroundColor Green

    # 5 App settings
    Write-Host "5 Adding app settings" -ForegroundColor Yellow

    # App settings (App Insights instrumentation key)
    $appSettingsName = 'APPINSIGHTS_INSTRUMENTATIONKEY'   
    $settingPath = "AppInsights-Instrumentation-Key"
    $secretKeyName = GetKeyVaultSecretKeyName `
        -Environment $Environment `
        -SettingPath $settingPath `
        -ExcelFilePath $settingsFilePath              
    $keyVaultSecretReference = "`"@Microsoft.KeyVault(SecretUri=https://$KeyVaultName.vault.azure.net/secrets/$secretKeyName/)`""

    az functionapp config appsettings set `
        --name $FunctionAppPrivateName `
        --resource-group $ResourceGroupName `
        --settings "$appSettingsName=$keyVaultSecretReference"        

    az functionapp config appsettings set `
        --name $FunctionAppPrivateName `
        --resource-group $ResourceGroupName `
        --settings "$appSettingsName=$keyVaultSecretReference" `
        --slot "staging"

    az functionapp config appsettings set `
        --name $FunctionAppPublicName `
        --resource-group $ResourceGroupName `
        --settings "$appSettingsName=$keyVaultSecretReference"

    az functionapp config appsettings set `
        --name $FunctionAppPublicName `
        --resource-group $ResourceGroupName `
        --settings "$appSettingsName=$keyVaultSecretReference" `
        --slot "staging"        
        
    # App settings (Integration App secret)
    $appSettingsName = 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'
    $settingPath = "Azure:Entra:IntegrationApp:Secret"
    $secretKeyName = GetKeyVaultSecretKeyName `
        -Environment $Environment `
        -SettingPath $settingPath `
        -ExcelFilePath $settingsFilePath              
    $keyVaultSecretReference = "`"@Microsoft.KeyVault(SecretUri=https://$KeyVaultName.vault.azure.net/secrets/$secretKeyName/)`""

    az functionapp config appsettings set `
        --name $FunctionAppPrivateName `
        --resource-group $ResourceGroupName `
        --settings "$appSettingsName=$keyVaultSecretReference"

    az functionapp config appsettings set `
        --name $FunctionAppPrivateName `
        --resource-group $ResourceGroupName `
        --settings "$appSettingsName=$keyVaultSecretReference" `
        --slot "staging"

    az functionapp config appsettings set `
        --name $FunctionAppPublicName `
        --resource-group $ResourceGroupName `
        --settings "$appSettingsName=$keyVaultSecretReference"

    az functionapp config appsettings set `
        --name $FunctionAppPublicName `
        --resource-group $ResourceGroupName `
        --settings "$appSettingsName=$keyVaultSecretReference" `
        --slot "staging"  

    Write-Host "5 App settings added" -ForegroundColor Green    

    # 6 Add subscription keys to key vault.
    Write-Host "6 Adding APIM subscription keys to key vault" -ForegroundColor Yellow
    $keyVaultSecretsScript = Find-FileByName -FileName "KeyVaultSecrets.ps1" -CurrentDirectory $rootDir
     
    # Get the PRIVATE secret name form the excel file
    $settingPath = "Azure:Apim:PrivateSubscription"
    $apimPrivateSubscriptionSecretName = GetKeyVaultSecretKeyName `
        -Environment $Environment `
        -SettingPath $settingPath `
        -ExcelFilePath $settingsFilePath    

    # Save the PRIVATE secret to key vault
    & $keyVaultSecretsScript `
        -keyVaultName $KeyVaultName `
        -secretName  $apimPrivateSubscriptionSecretName `
        -secretValue $apimPrivateSubscriptionPrimaryKey           

    # Get the PUBLIC secret name form the excel file        
    $settingPath = "Azure:Apim:PublicSubscription"
    $apimPublicSubscriptionSecretName = GetKeyVaultSecretKeyName `
        -Environment $Environment `
        -SettingPath $settingPath `
        -ExcelFilePath $settingsFilePath     

    # Save the PUBLIC secret to key vault
    & $keyVaultSecretsScript `
        -keyVaultName $KeyVaultName `
        -secretName $apimPublicSubscriptionSecretName  `
        -secretValue $apimPublicSubscriptionPrimaryKey            

    Write-Host "6 Subscription keys added to key vault" -ForegroundColor Green
    
    # 7 Add named values to APIM
    Write-Host "7 Adding APIM named values" -ForegroundColor Yellow
    $fnPrivateNamedValueId = 'private-function-resource-url'
    $fnPublicNamedValueId = 'public-function-resource-url'
    $privateXSubscriptionNamedValueId = 'private-x-subscription-id'
    $publicXSubscriptionNamedValueId = 'public-x-subscription-id'
    $ocpSubscriptionHeaderName = 'Ocp-Apim-Subscription-Key'
    $aesIv = 'cryptography-aes-iv'
    $aesIvSecretName = GetKeyVaultSecretKeyName `
        -Environment $Environment `
        -SettingPath 'Cryptography:Aes:Base64Iv' `
        -ExcelFilePath $settingsFilePath        
    $aesKey = 'cryptography-aes-key'
    $aesKeySecretName = GetKeyVaultSecretKeyName `
        -Environment $Environment `
        -SettingPath 'Cryptography:Aes:Base64Key' `
        -ExcelFilePath $settingsFilePath      
    $rsaPrivateKeyNamedValueId = 'cryptography-rsa-private-key'
    $rsaPrivateKeySecretName = GetKeyVaultSecretKeyName `
        -Environment $Environment `
        -SettingPath 'Cryptography:Rsa:PrivateKey' `
        -ExcelFilePath $settingsFilePath    

    & $apimNamedValuesScript `
        -ApimPrivateSubscriptionSecretName $apimPrivateSubscriptionSecretName `
        -ApimPublicSubscriptionSecretName $apimPublicSubscriptionSecretName `
        -ApimServiceName $ApimServiceName `
        -AuthClientId $AuthClientId `
        -CryptographyAesInitVectorNamedValueId $aesIv `
        -CryptographyAesInitVectorSecretName $aesIvSecretName `
        -CryptographyAesKeyNamedValueId $aesKey `
        -CryptographyAesKeySecretName $aesKeySecretName `
        -CryptographyRsaPrivateKeyNamedValueId $rsaPrivateKeyNamedValueId `
        -CryptographyRsaPrivateKeySecretName $rsaPrivateKeySecretName `
        -FunctionAppPrivateNamedValueId $fnPrivateNamedValueId `
        -FunctionAppPrivateUrl "https://$($privateFunctionApp.DefaultHostName)" `
        -FunctionAppPublicNamedValueId $fnPublicNamedValueId `
        -FunctionAppPublicUrl  "https://$($publicFunctionApp.DefaultHostName)" `
        -KeyVaultName $KeyVaultName `
        -PrivateSubscriptionKeyNamedValueId $privateXSubscriptionNamedValueId `
        -PrivateSubscriptionKeySecretName $apimPrivateSubscriptionSecretName `
        -PublicSubscriptionKeyNamedValueId $publicXSubscriptionNamedValueId `
        -PublicSubscriptionKeySecretName $apimPublicSubscriptionSecretName `
        -ResourceGroupName $ResourceGroupName 

    Write-Host "7 APIM named values added" -ForegroundColor Yellow        

    # 8 Set APIM policy 
    Write-Host "8 Setting APIM policy" -ForegroundColor Yellow
    $apimContext = New-AzApiManagementContext -ResourceGroupName $ResourceGroupName -ServiceName $ApimServiceName 

    # Get APIs information
    $allApis = az apim api list `
        --resource-group $ResourceGroupName `
        --service-name $ApimServiceName `
        -o json | ConvertFrom-Json

    $apis = $allApis | Where-Object { $_.name -eq $ApimPublicApiName -or $_.name -eq $ApimPrivateApiName }    

    if ($null -eq $apis) {
        Write-Host "APIs '$ApimPublicApiName' and '$ApimPrivateApiName' not found in APIM service '$ApimServiceName' in resource group '$ResourceGroupName'" -ForegroundColor Red
        Exit 1
    }    

    $publicApi = $apis | Where-Object { $_.name -eq $ApimPublicApiName }
    $privateApi = $apis | Where-Object { $_.name -eq $ApimPrivateApiName }    

    # Get APIM policy content    
    $rootDir = Split-Path -Path $parentDir -Parent 
    $apimPrivateFile = Find-FileByName -FileName "ApimPrivatePolicy.xml" -CurrentDirectory $rootDir
    $apimPublicFile = Find-FileByName -FileName "ApimPublicPolicy.xml" -CurrentDirectory $rootDir

    # Define the origins replacement as an object
    if ($Brand.ToLower() -eq 'Wwtp') {
        $originsReplacement = [PSCustomObject]@{
            Origins = @(
                "<origin>https://wewantto.party</origin>"
            )
        }
    }

    # Convert the array of origins into a single string, with each origin separated by a newline character
    $originsReplacementString = $originsReplacement.Origins -join "`n"

    # Set APIM policy for private API    
    Write-Host "Setting policy for private API" -ForegroundColor Yellow
    $apimPolicyContent = Get-ApimPolicyContent -filePath $apimPrivateFile
    $apimPolicyContent = SetCorsPolicy `
        -Environment $Environment `
        -apimPolicyContent $apimPolicyContent `
        -originsReplacementString $originsReplacementString
    $apimPolicyContent = $apimPolicyContent -replace '<<FNAP-URL>>', "{{$fnPrivateNamedValueId}}"
    $apimPolicyContent = $apimPolicyContent -replace '<<SUBSCRIPTION-KEY>>', $ocpSubscriptionHeaderName
    Set-AzApiManagementPolicy -Context $apimContext -ApiId $privateApi.name -Policy $apimPolicyContent -Format "rawxml"
    Write-Host "Policy set" -ForegroundColor Green        

    # Set APIM policy for public API 
    Write-Host "Setting policy for public API" -ForegroundColor Yellow
    $apimPolicyContent = Get-ApimPolicyContent -filePath $apimPublicFile
    $apimPolicyContent = SetCorsPolicy `
        -Environment $Environment `
        -apimPolicyContent $apimPolicyContent `
        -originsReplacementString $originsReplacementString
    $apimPolicyContent = $apimPolicyContent -replace '<<FNAP-URL>>', "{{$fnPublicNamedValueId}}"
    $apimPolicyContent = $apimPolicyContent -replace '<<SUBSCRIPTION-KEY>>', $ocpSubscriptionHeaderName
    Set-AzApiManagementPolicy -Context $apimContext -ApiId $publicApi.name -Policy $apimPolicyContent -Format "rawxml"
    Write-Host "8 APIM policy set" -ForegroundColor Green
}
catch {
    Write-Host "Failed to prcess API or APIM" -ForegroundColor Red
    Write-Host "File FnApps.ps1, line Number: $($_.InvocationInfo.ScriptLineNumber)"
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host "Stack Trace: $($_.Exception.StackTrace)"
    Exit 1
}
