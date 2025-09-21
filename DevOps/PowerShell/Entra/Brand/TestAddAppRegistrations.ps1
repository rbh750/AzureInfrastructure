. "$PSScriptRoot/../../FindFileByName.ps1"	
$parentDir = Split-Path -Path $PSScriptRoot -Parent 
$rootDir = Split-Path -Path $parentDir -Parent 
$psFile = Find-FileByName -FileName "AppRegistration.ps1" -CurrentDirectory $rootDir

#region "Integration App"

$processDev = $true
$env = "DEV"
$eApName = "Wwtp-Backend-Integration-12"
$eApNote = "This application is utilized by APIM for authentication purposes when accessing the function apps."
$createEnterpriseApplicaiton = $false
$ProcessingIntegrationAp = $true
$resetPermissions = $false
$tenantId = 'cbc31bc0-a781-4712-809b-3b404c5e19e2'
$keyVaultName = 'cognitus'


$permissionsPath = Find-FileByName -FileName "Integration-Permissions.json" -CurrentDirectory $rootDir   
$JsonPermissions = Get-Content -Path $permissionsPath -Raw | ConvertFrom-Json

# $rolesPath = Find-FileByName -FileName "Roles.json" -CurrentDirectory $rootDir
# $JsonRoles = Get-Content -Path $rolesPath -Raw | ConvertFrom-Json

# $scopesPath = Find-FileByName -FileName "Scopes.json" -CurrentDirectory $rootDir
# $JsonScopes = Get-Content -Path $scopesPath -Raw | ConvertFrom-Json

if ($processDev) {
    . $psFile `
        -CreateEnterpriseApplicaiton $createEnterpriseApplicaiton `
        -ProcessingIntegrationAp $ProcessingIntegrationAp `
        -ResetPermission $resetPermissions `
        -EApName $eApName `
        -EApNote $eApNote `
        -Environment $env `
        -JsonPermissions $JsonPermissions  `
        -JsonRoles $null `
        -JsonScopes $null `
        -KeyVaultName $keyVaultName `
        -TenantId $tenantId 
}

#endregion
