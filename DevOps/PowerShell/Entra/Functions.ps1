

#region "Roles Fns"

# Returns a collection of new roles to be added to the AD App.
function AddRolesFn {

    param (   
        [Parameter(Mandatory = $false)]
        [PSCustomObject[]] $Roles
    )        

    if ($Roles.Count -eq 0) {
        return
    }

    $newRoles = @()
    $newAllowedMemberypes = @()

    foreach ($r in $Roles) {
        foreach ($amt in $r.allowedMemberType) {
            $newAllowedMemberypes += $amt
        }

        $newRole = RoleBuilderFn -AllowedMemberType $newAllowedMemberypes -Description $r.description -DisplayName $r.displayName -Value $r.value
        $newRoles += $newRole
        $newAllowedMemberypes = @()
    }

    return $newRoles
}

# Returns a collection of existing and new roles to be added to the AD App.
function AppendRolesFn {

    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]] $Roles,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]] $currentRoles
    )    
    if (($Roles.Count -eq 0) -or ($null -eq $currentRoles)) {
        return $currentRoles
    }

    $newAllowedMemberypes = @()

    foreach ($r in $Roles) {
        $roleAlreadyAdded = ($currentRoles | Where-Object { $_.DisplayName -eq $r.displayName })

        if ($null -eq $roleAlreadyAdded) {
            foreach ($amt in $r.allowedMemberType) {
                $newAllowedMemberypes += $amt
            }

            $newAppRole = RoleBuilderFn -AllowedMemberType $newAllowedMemberypes -Description $r.description -DisplayName $r.displayName -Value $r.value
            $currentRoles += $newAppRole
            $newAllowedMemberypes = @()
        }
    }

    return $currentRoles
}

# Returns a new role object.
function RoleBuilderFn($AllowedMemberType, $Description, $DisplayName, $Value) {
    $Id = [Guid]::NewGuid().ToString()
    $role = [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphAppRole]::new()
    $role.AllowedMemberType = $AllowedMemberType
    $role.Description = $Description
    $role.DisplayName = $DisplayName
    $role.Id = $Id
    $role.IsEnabled = $true
    $role.Value = $Value
    return $role
}

#endregion

#region "Scopes Fns"

#  Returns a collection of new scopes to be added to the AD App.
function AddScopesFn {
    param (
        [Parameter(Mandatory = $false)]
        [PSCustomObject[]] $Scopes
    )

    if ($Scopes.Count -eq 0) {
        return
    }

    $newScopes = @()

    foreach ($r in $Scopes) {
        $ns = ScopeBuilderFn `
            -AdminConsentDescription $r.adminConsentDescription `
            -AdminConsentDisplayName $r.adminConsentDisplayName `
            -IsEnabled $r.isEnabled `
            -Type $r.Type `
            -UserConsentDescription $r.userConsentDescription `
            -UserConsentDisplayName $r.userConsentDisplayName `
            -Value $r.Value

        $newScopes += $ns
    }

    return $newScopes
}

# Returns a collection of existing and new scopes to be added to the AD App.
function AppendScopesFn {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]] $Scopes,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]] $currentScopes
    )

    if (($Scopes.Count -eq 0) -or ($null -eq $currentScopes)) {
        return $currentScopes
    }

    foreach ($r in $Scopes) {
        $scopeAlreadyAdded = ($currentScopes | Where-Object { $_.Value -eq $r.value })

        if ($null -eq $scopeAlreadyAdded) {
            $ns = ScopeBuilderFn `
                -AdminConsentDescription $r.adminConsentDescription `
                -AdminConsentDisplayName $r.adminConsentDisplayName `
                -IsEnabled $r.isEnabled `
                -Type $r.Type `
                -UserConsentDescription $r.userConsentDescription `
                -UserConsentDisplayName $r.userConsentDisplayName `
                -Value $r.Value

            $currentScopes += $ns
        }
    }

    return $currentScopes
}

# Returns a new scope object.
function ScopeBuilderFn($AdminConsentDescription, $AdminConsentDisplayName, $IsEnabled, $Type, $UserConsentDescription, $UserConsentDisplayName, $Value, $Id) {
    $ns = [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphPermissionScope]::new()
    $ns.AdminConsentDescription = $adminConsentDescription
    $ns.AdminConsentDisplayName = $adminConsentDisplayName
    $ns.IsEnabled = $isEnabled
    $ns.Type = $type
    $ns.UserConsentDescription = $userConsentDescription
    $ns.UserConsentDisplayName = $userConsentDisplayName
    $ns.Value = $Value

    if ($null -eq $Id) {
        $ns.Id = [Guid]::NewGuid().ToString()
    }
    else {
        $ns.Id = $Id
    }

    return $ns
}

#endregion

#region "Permissions Fns"

# $Permissions only contains external permissions therefore 
# internal application permissions defined in $Roles where addAsPermission equals true, 
# must be included in $Permissions before merging the new and existing permissions.
function AddInternalApplicationPermissionsToJsonPermissions($Permissions, $Roles) {

    $applicationPermissions = @()    
    $permissionsArr = @()

    foreach ($r in $Roles) {
        if ($r.addAsPermission) {
            $permissionId = ($adap.AppRole | Where-Object { $_.Value -eq $r.value }).Id
            $permissionsArr += [pscustomobject]@{ permissionId = $permissionId; type = 'Application' }
        }
    }

    if ($permissionsArr.Count -eq 0) {
        return $Permissions;
    }
    else {
        $applicationPermissions += [pscustomobject]@{
            apiId       = $adap.AppId
            permissions = $permissionsArr
        }

        if ($null -ne $Permissions) {
            $applicationPermissions += $Permissions
        }

        return $applicationPermissions
    }   
}

# $Permissions only contains external permissions therefore 
# internal delegated permissions defined in $Scopes where addAsPermission equals true, 
# must be included in $Permissions before merging the new and existing permissions.
function AddInternalDelegatedPermissionsToJsonPermissions($applicationPermissions, $Scopes) {

    $delegatedPermissions = @()  
    $permissionsArr = @()

    if ($null -eq $Scopes) {
        return $null;
    }

    $requiredResourceAccess = $adap.RequiredResourceAccess | Where-Object { $_.ResourceAppId -eq $adap.AppId }

    if (($null -ne $requiredResourceAccess.ResourceAppId) -and ($requiredResourceAccess.ResourceAccess | Where-Object { $_.Type -eq "Scope" }).Count -gt 0) {

        # There is at least one delgated permission for this $adap

        foreach ($i in $requiredResourceAccess.ResourceAccess) {
            $permissionsArr += [pscustomobject]@{ permissionId = $i.Id; type = $i.Type -eq "Scope" ? "Delegated" : "Application" }
        }
        
        foreach ($s in $Scopes) { 
            if ($s.addAsPermission) {
                $permissionId = ($adap.Api.Oauth2PermissionScope | Where-Object { $_.Value -eq $s.value }).Id
                $exisntingPermission = ($requiredResourceAccess.ResourceAccess | Where-Object { $_.Id -eq $permissionId }).Id

                if ($null -eq $exisntingPermission) {
                    # New permission.
                    $permissionsArr += [pscustomobject]@{ permissionId = $permissionId; type = 'Delegated' }
                }                
            }
        } 

        $permissionsArr += ($applicationPermissions | Where-Object { $_.apiId -eq $adap.AppId }).permissions

        $delegatedPermissions += [pscustomobject]@{
            apiId       = $adap.AppId
            permissions = $permissionsArr
        }
    }
    else {
        # There is not a delgated permission for this $adap

        foreach ($s in $Scopes) {       
            if ($s.addAsPermission) {
                $permissionsArr += [pscustomobject]@{ permissionId = ($adap.Api.Oauth2PermissionScope | Where-Object { $_.Value -eq $s.value }).Id; type = 'Delegated' }
            }
        } 
    
        $permissionsArr += ($applicationPermissions | Where-Object { $_.apiId -eq $adap.AppId }).Permissions 

        $delegatedPermissions += [pscustomobject]@{
            apiId       = $adap.AppId
            permissions = $permissionsArr
        }
    }

    $delegatedPermissions += ($applicationPermissions | Where-Object { $_.apiId -ne $adap.AppId })
    return $delegatedPermissions
}

function RequiredResourceAccessFn {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]] $Permissions
    )

    # Initialize an empty array to hold the required resource access objects
    $requiredResourceAccessArr = @()

    # Iterate through each permission in the provided Permissions array
    foreach ($nap in $Permissions) {
        $resourceAccessArr = @()

        # Iterate through each API ID in the Permissions array
        foreach ($resourceAppId in $Permissions.apiId) {
            if ($resourceAppId -ne $nap.resourceAppId) {
                # Find permissions that match the current API ID
                foreach ($p in ($Permissions | Where-Object { $_.apiId -eq $resourceAppId })) {

                    # Check if the API ID is not already in the required resource access array
                    if ($p.apiId -notin ($requiredResourceAccessArr.ResourceAppId)) {

                        # Iterate through each permission in the current permission object 
                        if (0 -ne $requiredResourceAccessArr.Count) {

                            # Where the API ID is not in the required resource access array
                            $perms = $p.permissions | Where-Object { $_.apiId -notin ($requiredResourceAccessArr.ResourceAppId) }
                        }
                        else {
                            $perms = $p.permissions
                        }                        
                        
                        foreach ($i in $perms) {
                            # Build the resource access object and add it to the resource access array
                            $resourceAccessArr += ResourceAccessBuilderFn $i.permissionId ($i.Type.ToLower() -eq "application" ? "Role" : "Scope")
                        }
                        # Build the required resource access object and add it to the required resource access array
                        $requiredResourcesAccess = RequiredResourceAccessBuilderFn $resourceAppId $resourceAccessArr
                        $resourceAccessArr = $null
                        [Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess[]]$requiredResourceAccessArr += $requiredResourcesAccess
                     }
                }
            }
        }
    }

    # If no required resource access objects were added, process the Permissions array again
    if ($requiredResourceAccessArr.Count -eq 0) {
        foreach ($p in $Permissions) {
            $resourceAccessArr = @()
            # Iterate through each permission in the current permission object
            foreach ($i in $p.Permissions) {
                # Build the resource access object and add it to the resource access array
                $resourceAccessArr += ResourceAccessBuilderFn $i.permissionId ($i.Type.ToLower() -eq "application" ? "Role" : "Scope")
            }
            # Build the required resource access object and add it to the required resource access array
            $requiredResourcesAccess = RequiredResourceAccessBuilderFn $p.apiId $resourceAccessArr
            [Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess[]]$requiredResourceAccessArr += $requiredResourcesAccess
        }
    }

    # Return the array of required resource access objects
    return $requiredResourceAccessArr
}

# Return a MicrosoftGraphResourceAccess object.
function ResourceAccessBuilderFn($id, $type) {
    $resourceAccess = [Microsoft.Graph.PowerShell.Models.MicrosoftGraphResourceAccess]::new()
    $resourceAccess.Id = $id
    $resourceAccess.Type = $type
    return $resourceAccess
}

# Return a new or existing MicrosoftGraphRequiredResourceAccess object: an array of app ids and resourceAccess.
function RequiredResourceAccessBuilderFn($resourceAppId, $resourceAccessArr) {
    $requiredResourceAccess = [Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess]::new()
    $requiredResourceAccess.ResourceAppId = $resourceAppId
    $requiredResourceAccess.ResourceAccess = $resourceAccessArr

    return $requiredResourceAccess
}


#endregion

#region "Preautohrized Applications"

# Applications that are allowed to ask for internal delegated permissions in the user consent screen (or by the admin).

function ApplicationsThatCanAskForInternalDelegatedPermissions {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]] $Scopes
    )
    
    # Initialize an array to hold the IMicrosoftGraphPreAuthorizedApplication objects
    $preAuthorizedApps = @()

    # Iterate over each scope and extract preAuthorizedApplications
    foreach ($scope in $Scopes) {
        foreach ($app in $scope.preAuthorizedApplications) {
            $preAuthorizedApp = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphPreAuthorizedApplication
            $preAuthorizedApp.AppId = $app.appId
            $preAuthorizedApp.DelegatedPermissionIds = $app.delegatedPermissionIds

            # Add the object to the array
            $preAuthorizedApps += $preAuthorizedApp
        }
    }

    return [Microsoft.Graph.PowerShell.Models.IMicrosoftGraphPreAuthorizedApplication[]] $preAuthorizedApps
}

function ApplicationsThatCanAskForInternalDelegatedPermissions2 {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]] $Scopes
    )

    $preAuthApps = @()
    $newPermissionAppIds = @()
   
    # Application ids and preauthorized apps. 
    $appAndPermissionsFromParam = GetApplicationsIdsFromScopeParameters $Scopes 

    foreach ($i in $appAndPermissionsFromParam  ) {
        $existing = $false

        foreach ($p in $adap.Api.PreAuthorizedApplication) {
            if ($i.appId -eq $p.AppId ) {
                $existing = $true
            }
        }

        if (!$existing) {
            $newPermissionAppIds += $i.appId
        }
    }

    foreach ($apid in $newPermissionAppIds) {
        $pa = [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphPreAuthorizedApplication]::new()
        $pa.AppId = $apid

        foreach ($i in  $appAndPermissionsFromParam | Where-Object { $_.appId -eq $apid }) {
            $pa.DelegatedPermissionId += $i.permissionId
        }

        $preAuthApps += $pa      
    }

    return $preAuthApps
}

# Extracts a dictionary of application ids and names from param scopes.
# This collection contains unique items.
function GetApplicationsIdsFromScopeParameters($Scopes) {
    $apps = @()

    # Group app names first.
    foreach ($s in $Scopes) {
        foreach ($a in $s.preAuthorizedApplications) {
            if (!$apps.Contains($a)) {
                $apps += [pscustomobject]@{
                    permissionName = $s.Value
                    permissionId   = ($adap.Api.Oauth2PermissionScope | Where-Object { $_.Value -eq $s.value }).Id
                    appName        = $a
                    appId          = $a.AppId
                }
            }
        }
    }

    return $apps
}

#endregion