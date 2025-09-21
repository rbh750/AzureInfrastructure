# |-------------|-------------|----------|
# | Type        | External    | Internal |
# |-------------|-------------|----------|
# | Application | Permissions | Roles    |
# | Delegated   | Permissions | Scopes   |   
# |-------------|-------------|----------| 

# Permissions are set up within the API permissions section and can include 
# application and delegated permissions from ANOTHER application.
# Roles are set in App roles.
# Scopes are set in expose an API.

# Permissions reference: https://learn.microsoft.com/en-us/graph/permissions-reference?form=MG0AV3

param (
    [bool]$CreateEnterpriseApplication,
    [bool]$ProcessingBackendApp,
    [bool]$ResetPermissions,
    [string]$AppType, 
    [string]$AuthClientId,
    [string]$AuthClientSecret,
    [string]$Brand, 
    [string]$EApExcelClientIdSettingPath, 
    [string]$EApExcelSecretSettingPath, 
    [string]$EApName,
    [string]$EApNote,
    [string]$Environment,
    [string]$KeyVaultName,
    [string]$SubscriptionId,
    [string]$TenantId
)

# Check if the last version of Microsoft Graph module is installed.
$latestVersion = (Find-Module -Name Microsoft.Graph).Version
$installedVersion = Get-InstalledModule -Name Microsoft.Graph -ErrorAction SilentlyContinue

if ($null -eq $installedVersion -or $installedVersion.Version -lt $latestVersion) {
    Write-Host "Updating Microsoft.Graph module to latest version $latestVersion..." -ForegroundColor Yellow
    if ($env:BUILD_BUILDID) {
        Install-Module -Name Microsoft.Graph -Scope CurrentUser -AllowClobber -Force
    }
    else {
        Install-Module -Name Microsoft.Graph -Scope AllUsers -AllowClobber -Force
    }
}

if (-not (Get-Module -Name Microsoft.Graph)) {
    Write-Host "Importing Microsoft.Graph module" -ForegroundColor Yellow
    Import-Module Microsoft.Graph
}

if (-not (Get-Module -ListAvailable -Name Az.Resources)) {
    Write-Host "Az.Resources module not found. Installing..."
    if ($env:BUILD_BUILDID) {
        Install-Module -Name Az.Resources -Scope CurrentUser -AllowClobber -Force
    }
    else {
        Install-Module -Name Az.Resources -Scope AllUsers -AllowClobber -Force
    }
}

if (-not (Get-Module -Name Az.Resources)) {
    Write-Host "Importing Az.Resources module" -ForegroundColor Yellow
    Import-Module Az.Resources
}

Write-Host "Processing Entra App: $($EApName)" -ForegroundColor Yellow

try {   
    function Get-AdApplicationByName {
        param (
            [Parameter(Mandatory = $true)]
            [string]$EntraApName,
            
            [Parameter(Mandatory = $true)]
            [hashtable]$Headers
        )
    
        $uri = "https://graph.microsoft.com/v1.0/applications?`$filter=displayName eq '$EntraApName'"
        $eaps = Invoke-RestMethod -Uri $uri -Headers $Headers -Method Get
        if ($eaps.value.Count -gt 0) {
            return $eaps.value[0]
        }
        return $null
    }    

    # As of January 1, 2025, $eAp.Api.Oauth2PermissionScope is returning incorrect IDs. 
    # Therefore, it is necessary to use the Az.Resources module.
    function Get-Oauth2PermissionScopesById {
        param (
            [Parameter(Mandatory = $true)]
            [string]$AppId
        )

        $oauth2PermissionScopes = az ad app show --id $appId --query "api.oauth2PermissionScopes" --output json
        $oauth2PermissionScopesObject = $oauth2PermissionScopes | ConvertFrom-Json

        return  [Microsoft.Graph.PowerShell.Models.MicrosoftGraphPermissionScope[]] $oauth2PermissionScopesObject
    }

    . "$PSScriptRoot/../FindFileByName.ps1"
    $parentDir = Split-Path -Path $PSScriptRoot -Parent 
    $rootDir = Split-Path -Path $parentDir -Parent 
    $functionsFile = Find-FileByName -FileName "Functions.ps1" -CurrentDirectory $rootDir    
    . $functionsFile    
    $settingsManager = Find-FileByName -FileName "SettingsManager.ps1" -CurrentDirectory $rootDir
    . $settingsManager
    $keyVaultRbacRolesFile = Find-FileByName -FileName "KeyVaultRbacRoles.ps1" -CurrentDirectory $rootDir

    [PSCustomObject[]]$jsonPermissions = $null
    [PSCustomObject[]]$jsonRoles = $null
    [PSCustomObject[]]$jsonScopes = $null

    # Web apps require callback urls
    $webApp = $false

    # Retrieve permissions for the Entra app
    $entraDir = Find-DirectoryByName -DirectoryName "Entra" -CurrentDirectory $rootDir

    if ($Brand.ToLower() -eq 'wwtp') {
        $wwtpDir = Find-DirectoryByName -DirectoryName "Wwtp" -CurrentDirectory $entraDir

        if ($AppType -eq 'webUiClient') {
            $permissionsPath = Find-FileByName -FileName "WebUiClient-Permissions.json" -CurrentDirectory $wwtpDir
            $jsonPermissions = Get-Content -Path $permissionsPath -Raw | ConvertFrom-Json
            $webApp = $true
        }
        elseif ($AppType -eq 'webUiVendor') {
            $permissionsPath = Find-FileByName -FileName "WebUiVendor-Permissions.json" -CurrentDirectory $wwtpDir
            $jsonPermissions = Get-Content -Path $permissionsPath -Raw | ConvertFrom-Json
            $webApp = $true
        }    
        elseif ($AppType -eq 'webUiStaff') {
            $permissionsPath = Find-FileByName -FileName "WebUiStaff-Permissions.json" -CurrentDirectory $wwtpDir
            $jsonPermissions = Get-Content -Path $permissionsPath -Raw | ConvertFrom-Json
            $webApp = $true
        }                      
    }

    # Create a SecureString object from the client secret
    $secureClientSecret = ConvertTo-SecureString -String $AuthClientSecret -AsPlainText -Force

    # Create a PSCredential object
    # $authCredentials = New-Object `
    #     -TypeName System.Management.Automation.PSCredential `
    #     -ArgumentList $AuthClientId, $secureClientSecret

    $authCredentials = New-Object System.Management.Automation.PSCredential($AuthClientId, $secureClientSecret)

    # Remove cached credentials for the current session before connecting to Microsoft Graph
    Disconnect-MgGraph -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
    Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $authCredentials 
    az account set --subscription $SubscriptionId

    # Get the access token using Azure CLI
    $azToken = az account get-access-token --resource https://graph.microsoft.com | ConvertFrom-Json
    $accessToken = $azToken.accessToken    
    $headers = @{
        Authorization  = "Bearer $accessToken"
        "Content-Type" = "application/json"
    }     

    #region "1: Create new AD App?"

    $eAp = Get-AdApplicationByName -EntraApName $EApName -headers $headers

    if ($null -eq $eAp) {

        # Create the new app registration
        Write-Host "Creating app registration and setting RBAC roles in key vault" -ForegroundColor Yellow

        $newAppBody = @{
            displayName    = $EApName
            signInAudience = "AzureADMyOrg"
            notes          = $EApNote 
        } | ConvertTo-Json      
        
        $eAp = Invoke-RestMethod `
            -Method Post `
            -Uri "https://graph.microsoft.com/v1.0/applications" `
            -Headers $headers `
            -Body $newAppBody

        Start-Sleep -Seconds 10

        # Create service principal for the new app registration
        New-MgServicePrincipal -AppId $eAp.AppId -DisplayName $EApName

        & $keyVaultRbacRolesFile `
            -KeyVaultName $KeyVaultName `
            -ApplicationClientId $eAp.AppId `
            -AdminContributorRole $true 

        $eAp = Get-AdApplicationByName -EntraApName $EApName -headers $headers
        Write-Host "App registration created and permission granted in key vault" -ForegroundColor Green
    }


    #endregion

    #region "2 URI identifier"

    # Because the URI identifier is the app id, it must be updated after the app has been created.
    [String[]]$identifierUri = "api://" + $eAp.AppId
    Update-MgApplication -ApplicationId $eAp.Id -IdentifierUris $identifierUri

    #endregion

    #region "3 Reset permissions"

    # Disable all permissions
    $currentPermissions = @()
    Update-MgApplication -ApplicationId $eAp.Id -RequiredResourceAccess $currentPermissions
    $eAp = Get-AdApplicationByName -EntraApName $EApName -headers $headers

    # Disable all roles
    $currentRoles = $eAp.AppRoles
    $convertedRoles = @()
    foreach ($role in $currentRoles) {
        $convertedRole = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphAppRole
        $convertedRole.AllowedMemberTypes = $role.AllowedMemberTypes
        $convertedRole.Description = $role.Description
        $convertedRole.DisplayName = $role.DisplayName
        $convertedRole.Id = $role.Id
        $convertedRole.IsEnabled = $false
        $convertedRole.Origin = $role.Origin
        $convertedRole.Value = $role.Value
        $convertedRoles += $convertedRole
    }

    if ($convertedRoles.Count -gt 0) {
        Update-MgApplication -ApplicationId $eAp.Id -AppRole $convertedRoles
        $eAp = Get-AdApplicationByName -EntraApName $EApName -headers $headers
    }

    # Disable all scopes
    $currentScopes = $eAp.Api.Oauth2PermissionScopes
    $convertedScopes = @()
    foreach ($scope in $currentScopes) {
        $convertedScope = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphPermissionScope
        $convertedScope.AdminConsentDescription = $scope.AdminConsentDescription
        $convertedScope.AdminConsentDisplayName = $scope.AdminConsentDisplayName
        $convertedScope.Id = $scope.Id
        $convertedScope.IsEnabled = $false
        $convertedScope.Type = $scope.Type
        $convertedScope.UserConsentDescription = $scope.UserConsentDescription
        $convertedScope.UserConsentDisplayName = $scope.UserConsentDisplayName
        $convertedScope.Value = $scope.Value
        $convertedScopes += $convertedScope
    }

    if ($convertedScopes.Count -gt 0) {
        $oauth2PermissionScopes = [Microsoft.Graph.PowerShell.Models.MicrosoftGraphPermissionScope[]]$convertedScopes
        Update-MgApplication -ApplicationId $eAp.Id -Api @{ Oauth2PermissionScopes = $oauth2PermissionScopes }
        $eAp = Get-AdApplicationByName -EntraApName $EApName -headers $headers
    }

    if ($ResetPermissions) {        

        # Remove all roles
        $currentRoles = @()
        Update-MgApplication -ApplicationId $eAp.Id -AppRole $currentRoles
        $eAp = Get-AdApplicationByName -EntraApName $EApName -headers $headers

        # Remove all scopes
        $currentScopes = @()
        Update-MgApplication -ApplicationId $eAp.Id -Api @{ Oauth2PermissionScopes = $currentScopes }
        $eAp = Get-AdApplicationByName -EntraApName $EApName -headers $headers   
    } 

    #endregion

    #region "3: Upsert Roles = internal application permissions."

    if (![string]::IsNullOrEmpty($jsonRoles)) {

        # Existing Ad App roles.
        $currentRoles = $eAp.appRoles

        # Set up roles to be added or updated.
        if ($currentRoles.Count -eq 0) {

            # New collection of roles to be submitted.
            $currentRoles = AddRolesFn $jsonRoles
        }
        else {

            # Append to the collection of roles to be submitted.
            $convertedRoles = @()
            foreach ($role in $currentRoles) {
                $convertedRole = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphAppRole
                $convertedRole.AllowedMemberTypes = $role.AllowedMemberTypes | ForEach-Object { [string]$_ }
                $convertedRole.Description = $role.Description
                $convertedRole.DisplayName = $role.DisplayName
                $convertedRole.Id = $role.Id
                $convertedRole.IsEnabled = $role.IsEnabled
                $convertedRole.Value = $role.Value
                $convertedRoles += $convertedRole
            }            
            $stagedRoles = AppendRolesFn $jsonRoles $convertedRoles
        }

        # Submit staged roles.
        Update-MgApplication -ApplicationId $eAp.Id -AppRole $stagedRoles
        $eAp = Get-AdApplicationByName -EntraApName $EApName -headers $headers
    }

    #endregion

    #region "4: Upsert Scopes = internal delegated permissions and pre authorized applications"

    if (![string]::IsNullOrEmpty($jsonScopes)) {
        $currentScopes = Get-Oauth2PermissionScopesById -AppId $eAp.id

        # Set up scopes to be added or updated.
        if ($null -eq $currentScopes) {
            $currentScopes = AddScopesFn($jsonScopes)
        }
        else {
            $currentScopes = AppendScopesFn $jsonScopes $currentScopes
        }

        $oauth2PermissionScopes = [Microsoft.Graph.PowerShell.Models.MicrosoftGraphPermissionScope[]] $currentScopes
        Update-MgApplication -ApplicationId $eAp.Id -Api @{ Oauth2PermissionScopes = $oauth2PermissionScopes }
        $eAp = Get-AdApplicationByName -EntraApName $EApName -headers $headers    
    }

    #endregion

    #region "5 Pre authorized applications to use scopes."

    if (![string]::IsNullOrEmpty($jsonScopes)) {

        foreach ($scope in $jsonScopes) {            
            foreach ($preAuthApp in $scope.preAuthorizedApplications) {
                $trustedAdap = Get-AdApplicationByName -EntraApName $preAuthApp.name -headers $headers

                # Populate the app ids of the authorized applications.
                $preAuthApp.appId = $trustedAdap.appId

                foreach ($jsonScope in $jsonScopes) {
                    if ($jsonScope.value -eq $scope.value) {
                        foreach ($jsonPreAuthApp in $jsonScope.preAuthorizedApplications) {
                            if ($jsonPreAuthApp.name -eq $preAuthApp.name) {
                                $jsonPreAuthApp.appId = $trustedAdap.appId
                            }
                        }
                    }
                }

                # Populate the delegated permission ids of each pre authorized application.
                $oauth2PermissionScopes = Get-Oauth2PermissionScopesById -AppId $eAp.id
                
                foreach ($p in $oauth2PermissionScopes) {
                    if ($p.value -eq $scope.value) {
                        foreach ($jsonScope in $jsonScopes) {
                            if ($jsonScope.value -eq $scope.value) {
                                foreach ($jsonPreAuthApp in $jsonScope.preAuthorizedApplications) {
                                    if ($jsonPreAuthApp.name -eq $preAuthApp.name) {
                                        $jsonPreAuthApp.delegatedPermissionIds += $p.id
                                    }
                                }
                            }
                        }
                    }
                }            
            }
        }
    
        $preAuthorizedApplications = ApplicationsThatCanAskForInternalDelegatedPermissions $jsonScopes
        if ($null -ne $preAuthorizedApplications) {
            Update-MgApplication -ApplicationId $eAp.Id -Api @{ PreAuthorizedApplications = $preAuthorizedApplications }
            $eAp = Get-AdApplicationByName -EntraApName $EApName -headers $headers
        }
    }

    #endregion

    #region "6 Add roles and scopes from another application to permissions."

    if (![string]::IsNullOrEmpty($jsonPermissions)) {

        $requiredPermissions = RequiredResourceAccessFn -Permissions $jsonPermissions 

        if ($null -ne $requiredPermissions) {
            Update-MgApplication -ApplicationId $eAp.Id -RequiredResourceAccess $requiredPermissions
            $eAp = Get-AdApplicationByName -EntraApName $EApName -headers $headers         
        }
    }

    #endregion

    #region "7 Token version"

    $api = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphApiApplication
    $api.RequestedAccessTokenVersion = 2
    
    # Convert each PSCustomObject in Oauth2PermissionScopes to the correct type
    $oauth2PermissionScopes = @()
    foreach ($scope in $eAp.api.Oauth2PermissionScopes) {
        $permissionScope = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphPermissionScope
        $permissionScope.AdminConsentDescription = $scope.adminConsentDescription
        $permissionScope.AdminConsentDisplayName = $scope.adminConsentDisplayName
        $permissionScope.Id = $scope.id
        $permissionScope.IsEnabled = $scope.isEnabled
        $permissionScope.Type = $scope.type
        $permissionScope.UserConsentDescription = $scope.userConsentDescription
        $permissionScope.UserConsentDisplayName = $scope.userConsentDisplayName
        $permissionScope.Value = $scope.value
        $oauth2PermissionScopes += $permissionScope
    }
    
    $api.Oauth2PermissionScopes = $oauth2PermissionScopes
     
    # Convert each PSCustomObject in PreAuthorizedApplications to the correct type
    $preAuthorizedApplications = @()
    foreach ($app in $eAp.api.PreAuthorizedApplications) {
        $preAuthorizedApp = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphPreAuthorizedApplication
        $preAuthorizedApp.AppId = $app.appId
        $preAuthorizedApp.DelegatedPermissionIds = $app.delegatedPermissionIds
        $preAuthorizedApplications += $preAuthorizedApp
    }
    
    if ($preAuthorizedApplications.Count -gt 0) {
        $api.PreAuthorizedApplications = $preAuthorizedApplications
        Update-MgApplication -ApplicationId $eAp.Id -Api $api
        $eAp = Get-AdApplicationByName -EntraApName $EApName -headers $headers
    }
  
    #endregion

    #region "8 Enterprise application"

    if ($CreateEnterpriseApplication) {

        $servicePrincipal = Get-MgServicePrincipal -Filter "displayName eq '$EApName'"

        if ($null -eq $servicePrincipal) {
            New-MgServicePrincipal -AppId $eAp.AppId 
            $servicePrincipal = Get-MgServicePrincipal -Filter "displayName eq '$EApName'"
        }
    
        # Update the service principal's app roles
        $servicePrincipal.AppRoles = $eAp.AppRole
        Update-MgServicePrincipal -ServicePrincipalId $servicePrincipal.Id -AppRoles $servicePrincipal.AppRoles
    
        # Set AppRoleAssignmentRequired to true
        Update-MgServicePrincipal -ServicePrincipalId $servicePrincipal.Id -AppRoleAssignmentRequired 
    }
    
    #endregion

    #region "9 Client Id and secret"

    if ($ProcessingBackendApp -eq $true) { 
        $settingsFilePath = Find-FileByName -FileName "SettingsIndex.xlsx" -CurrentDirectory $rootDir   

        # Get the secret name form the excel file
        $secretKeyName = GetKeyVaultSecretKeyName `
            -Environment $Environment `
            -SettingPath $EApExcelSecretSettingPath `
            -ExcelFilePath $settingsFilePath

        # Add secret to the app registration
        $startDate = Get-Date
        $endDate = $startDate.AddMonths(18)    
        $stringBytes = [System.Text.Encoding]::UTF8.GetBytes($secretKeyName)
        $encodedString = [Convert]::ToBase64String($stringBytes)    
        $password = New-AzADAppCredential -StartDate $startDate -EndDate $endDate -ObjectId $eAp.Id -CustomKeyIdentifier $encodedString

        # Add the secret to the key vault
        $keyVaultPath = Find-FileByName -FileName "KeyVaultSecrets.ps1" -CurrentDirectory $rootDir    
        . $keyVaultPath `
            -keyVaultName $KeyVaultName `
            -secretName $secretKeyName `
            -secretValue $password.SecretText
    
        # Set the secret value in the excel file
        SetSettingValue `
            -Environment $Environment `
            -SettingPath $EApExcelSecretSettingPath `
            -SettingValue $password.SecretText `
            -ExcelFilePath $settingsFilePath

        # Set the client Id value in the excel file
        SetSettingValue `
            -Environment $Environment `
            -SettingPath $EApExcelClientIdSettingPath `
            -SettingValue $eAp.AppId `
            -ExcelFilePath $settingsFilePath
    }

    #endregion

    #region "10: Web app platform and info sections"

    if ($webApp -eq $true) {

        if ($Brand.ToLower() -eq 'wwtp') {
            $homePageUrl = "https://www.wewantto.party"
            $logoutUrl = "https://www.wewantto.party/logout"
            $redirectUris = @( "https://www.wewantto.party")
            $privacyStatementUrl = "https://www.wewantto.party/privacystatement"
            $termsOfServiceUrl = "https://www.wewantto.party/termsofservice"
    
            if ($Environment -eq 'dev' ) {
                $redirectUris += "https://oauth.pstmn.io/v1/callback"
                $redirectUris += "https://localhost:7029"
            }
        }

        # Get the current manifest
        $currentManifest = Get-MgApplication -ApplicationId $eAp.Id

        # Update the current manifest with new web settings
        $currentManifest.web = @{
            homePageUrl           = $homePageUrl
            logoutUrl             = $logoutUrl
            redirectUris          = $redirectUris
            implicitGrantSettings = @{
                enableIdTokenIssuance     = $true
                enableAccessTokenIssuance = $false
            }
        }

        # Update the current manifest with new info settings
        $currentManifest.info = @{
            logoUrl             = $null
            marketingUrl        = $null
            privacyStatementUrl = $PrivacyStatementUrl
            supportUrl          = $null
            termsOfServiceUrl   = $TermsOfServiceUrl
        }

        # Update the application
        Update-MgApplication -ApplicationId $eAp.Id -BodyParameter $currentManifest
    }

    #endregion

    Write-Host "Entra App: $($EApName) has been processed successfully" -ForegroundColor Green
}
catch {
    Write-Host "Failed to prcess Entra Apps" -ForegroundColor Red
    Write-Host "File AppRegistration.ps1, line Number: $($_.InvocationInfo.ScriptLineNumber)"
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host "Stack Trace: $($_.Exception.StackTrace)"
    Exit 1
}