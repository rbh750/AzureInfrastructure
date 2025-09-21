param(
    [string]$ApimPrivateSubscriptionSecretName,   
    [string]$ApimPublicSubscriptionSecretName,
    [string]$ApimServiceName,
    [string]$AuthClientId,
    [string]$CryptographyAesInitVectorNamedValueId, 
    [string]$CryptographyAesInitVectorSecretName, 
    [string]$CryptographyAesKeyNamedValueId, 
    [string]$CryptographyAesKeySecretName, 
    [string]$CryptographyRsaPrivateKeyNamedValueId, 
    [string]$CryptographyRsaPrivateKeySecretName, 
    [string]$FunctionAppPrivateNamedValueId,
    [string]$FunctionAppPrivateUrl,
    [string]$FunctionAppPublicNamedValueId,    
    [string]$FunctionAppPublicUrl,
    [string]$KeyVaultName,
    [string]$PrivateSubscriptionKeyNamedValueId,
    [string]$PrivateSubscriptionKeySecretName, 
    [string]$PublicSubscriptionKeyNamedValueId,
    [string]$PublicSubscriptionKeySecretName, 
    [string]$ResourceGroupName
)

Write-Host "ResourceGroupName at start: $ResourceGroupName"

# Check if the last version of Microsoft Graph module is installed.
$latestVersion = (Find-Module -Name Az.ApiManagement).Version
$installedVersion = Get-InstalledModule -Name Az.ApiManagement -ErrorAction SilentlyContinue

if ($null -eq $installedVersion -or $installedVersion.Version -lt $latestVersion) {
    Write-Host "Updating Az.ApiManagement module to latest version $latestVersion..." -ForegroundColor Yellow
    if ($env:BUILD_BUILDID) {
        Install-Module -Name Az.ApiManagement -Scope CurrentUser -AllowClobber -Force
    }
    else {
        Install-Module -Name Az.ApiManagement -Scope AllUsers -AllowClobber -Force
    }
}

if (-not (Get-Module -Name Az.ApiManagement)) {
    Write-Host "Importing Az.ApiManagement module" -ForegroundColor Yellow
    Import-Module Az.ApiManagement
}
  
# Check and install the Az.Functions module if not already installed
$latestVersion = (Find-Module -Name Az.Functions).Version
$installedVersion = Get-InstalledModule -Name Az.Functions -ErrorAction SilentlyContinue

if ($null -eq $installedVersion -or $installedVersion.Version -lt $latestVersion) {
    Write-Host "Updating Az.Functions module to latest version $latestVersion..." -ForegroundColor Yellow
    Install-Module -Name Az.Functions -Scope AllUsers -AllowClobber -Force
}

if (-not (Get-Module -Name Az.Functions)) {
    Write-Host "Importing Az.Functions module" -ForegroundColor Yellow
    Import-Module Az.Functions
}

. "$PSScriptRoot/FindFileByName.ps1" 
$parentDir = Split-Path -Path $PSScriptRoot -Parent   
$rootDir = Split-Path -Path $parentDir -Parent 
$keyVaultRbacRolesScript = Find-FileByName -FileName "KeyVaultRbacRoles.ps1" -CurrentDirectory $rootDir

try {
  
    Write-Host "Setting APIs RBAC roles" -ForegroundColor Yellow
    $apim = Get-AzApiManagement -ResourceGroupName $ResourceGroupName -Name $ApimServiceName
    $managedIdentityClientId = $apim.Identity.PrincipalId

    & $keyVaultRbacRolesScript `
        -KeyVaultName $KeyVaultName `
        -ApplicationClientId $managedIdentityClientId `
        -AdminContributorRole $false

    Write-Host "Permissions granted" -ForegroundColor Green

    Write-Host "Processing APIM named values" -ForegroundColor Yellow  

    $apimContext = New-AzApiManagementContext -ResourceGroupName $ResourceGroupName -ServiceName $ApimServiceName 

    # Integration Client ID
    $nv = 'entra-integration-client-id'
    $namedValue = Get-AzApiManagementNamedValue -Context $apimContext -Name $nv -ErrorAction SilentlyContinue
    if ($namedValue) {
        Set-AzApiManagementNamedValue `
            -Context $apimContext `
            -Name $nv `
            -NamedValueId $nv `
            -Value $AuthClientId
    }
    else {
        New-AzApiManagementNamedValue `
            -Context $apimContext `
            -Name $nv `
            -NamedValueId $nv `
            -Value $AuthClientId
    }
  
    # Private function app URL
    $namedValue = Get-AzApiManagementNamedValue -Context $apimContext -Name $FunctionAppPrivateNamedValueId -ErrorAction SilentlyContinue
    if ($namedValue) {
        Set-AzApiManagementNamedValue `
            -Context $apimContext `
            -Name $FunctionAppPrivateNamedValueId `
            -NamedValueId $FunctionAppPrivateNamedValueId `
            -Value $FunctionAppPrivateUrl
    }
    else {
        New-AzApiManagementNamedValue `
            -Context $apimContext `
            -Name $FunctionAppPrivateNamedValueId `
            -NamedValueId $FunctionAppPrivateNamedValueId `
            -Value $FunctionAppPrivateUrl
    }
  
    # Public function app URL
    $namedValue = Get-AzApiManagementNamedValue -Context $apimContext -Name $FunctionAppPublicNamedValueId -ErrorAction SilentlyContinue
    if ($namedValue) {
        Set-AzApiManagementNamedValue `
            -Context $apimContext `
            -Name $FunctionAppPublicNamedValueId `
            -NamedValueId $FunctionAppPublicNamedValueId `
            -Value $FunctionAppPublicUrl
    }
    else {
        New-AzApiManagementNamedValue `
            -Context $apimContext `
            -Name $FunctionAppPublicNamedValueId `
            -NamedValueId $FunctionAppPublicNamedValueId `
            -Value $FunctionAppPublicUrl
    }

    # Private Subscription Key (Key Vault Reference)
    $namedValue = Get-AzApiManagementNamedValue -Context $apimContext -Name $PrivateSubscriptionKeyNamedValueId -ErrorAction SilentlyContinue
    $secretIdentifier = "https://{0}.vault.azure.net/secrets/{1}" -f $KeyVaultName, $PrivateSubscriptionKeySecretName
    $keyvault = New-AzApiManagementKeyVaultObject -SecretIdentifier $secretIdentifier 

    if ($namedValue) {
        Set-AzApiManagementNamedValue `
            -Context $apimContext `
            -KeyVault $keyvault `
            -Name $PrivateSubscriptionKeyNamedValueId `
            -NamedValueId $PrivateSubscriptionKeyNamedValueId `
            -Secret
    }
    else {
        New-AzApiManagementNamedValue `
            -Context $apimContext `
            -KeyVault $keyvault `
            -NamedValueId $PrivateSubscriptionKeyNamedValueId `
            -Name $PrivateSubscriptionKeyNamedValueId `
            -Secret
    }

    # Public Subscription Key (Key Vault Reference)
    $namedValue = Get-AzApiManagementNamedValue -Context $apimContext -Name $PublicSubscriptionKeyNamedValueId -ErrorAction SilentlyContinue
    $secretIdentifier = "https://{0}.vault.azure.net/secrets/{1}" -f $KeyVaultName, $PublicSubscriptionKeySecretName
    $keyvault = New-AzApiManagementKeyVaultObject -SecretIdentifier $secretIdentifier 

    if ($namedValue) {
        Set-AzApiManagementNamedValue `
            -Context $apimContext `
            -KeyVault $keyvault `
            -Name $PublicSubscriptionKeyNamedValueId `
            -NamedValueId $PublicSubscriptionKeyNamedValueId `
            -Secret
    }
    else {
        New-AzApiManagementNamedValue `
            -Context $apimContext `
            -KeyVault $keyvault `
            -NamedValueId $PublicSubscriptionKeyNamedValueId `
            -Name $PublicSubscriptionKeyNamedValueId `
            -Secret
    }

    # AES initialization vector for validating the visitor id.  
    $namedValue = Get-AzApiManagementNamedValue -Context $apimContext -Name $CryptographyAesInitVectorNamedValueId -ErrorAction SilentlyContinue
    $secretIdentifier = "https://{0}.vault.azure.net/secrets/{1}" -f $KeyVaultName, $CryptographyAesInitVectorSecretName
    $keyvault = New-AzApiManagementKeyVaultObject -SecretIdentifier $secretIdentifier 

    if ($namedValue) {
        Set-AzApiManagementNamedValue `
            -Context $apimContext `
            -KeyVault $keyvault `
            -Name $CryptographyAesInitVectorNamedValueId `
            -NamedValueId $CryptographyAesInitVectorNamedValueId `
            -Secret
    }
    else {
        New-AzApiManagementNamedValue `
            -Context $apimContext `
            -KeyVault $keyvault `
            -NamedValueId $CryptographyAesInitVectorNamedValueId `
            -Name $CryptographyAesInitVectorNamedValueId `
            -Secret
    }    

    # AES Key for validating the visitor id.  
    $namedValue = Get-AzApiManagementNamedValue -Context $apimContext -Name $CryptographyAesKeyNamedValueId -ErrorAction SilentlyContinue
    $secretIdentifier = "https://{0}.vault.azure.net/secrets/{1}" -f $KeyVaultName, $CryptographyAesKeySecretName
    $keyvault = New-AzApiManagementKeyVaultObject -SecretIdentifier $secretIdentifier 

    if ($namedValue) {
        Set-AzApiManagementNamedValue `
            -Context $apimContext `
            -KeyVault $keyvault `
            -Name $CryptographyAesKeyNamedValueId `
            -NamedValueId $CryptographyAesKeyNamedValueId `
            -Secret
    }
    else {
        New-AzApiManagementNamedValue `
            -Context $apimContext `
            -KeyVault $keyvault `
            -NamedValueId $CryptographyAesKeyNamedValueId `
            -Name $CryptographyAesKeyNamedValueId `
            -Secret
    }        

    # Private RSA Key for validating the auth token issuer signature  
    $namedValue = Get-AzApiManagementNamedValue -Context $apimContext -Name $CryptographyRsaPrivateKeyNamedValueId -ErrorAction SilentlyContinue
    $secretIdentifier = "https://{0}.vault.azure.net/secrets/{1}" -f $KeyVaultName, $CryptographyRsaPrivateKeySecretName
    $keyvault = New-AzApiManagementKeyVaultObject -SecretIdentifier $secretIdentifier 

    if ($namedValue) {
        Set-AzApiManagementNamedValue `
            -Context $apimContext `
            -KeyVault $keyvault `
            -Name $CryptographyRsaPrivateKeyNamedValueId `
            -NamedValueId $CryptographyRsaPrivateKeyNamedValueId `
            -Secret
    }
    else {
        New-AzApiManagementNamedValue `
            -Context $apimContext `
            -KeyVault $keyvault `
            -NamedValueId $CryptographyRsaPrivateKeyNamedValueId `
            -Name $CryptographyRsaPrivateKeyNamedValueId `
            -Secret
    }    

    Write-Host "APIM named values processed" -ForegroundColor Green
}
catch {
    Write-Host "Failed to prcess APIM named values" -ForegroundColor Red
    Write-Host "File ApimNamedValues.ps1, line Number: $($_.InvocationInfo.ScriptLineNumber)"
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host "Stack Trace: $($_.Exception.StackTrace)"
    Exit 1
}