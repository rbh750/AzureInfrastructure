param (
    [string]$KeyVaultName,
    [string]$ApplicationClientId,
    [bool]$AdminContributorRole = $true
)

try {
    # Set RBAC roles for the Key Vault
    Write-Host "Checking if RBAC roles for Key Vault '$KeyVaultName' are already set for SPN '$ApplicationClientId'" -ForegroundColor Yellow

    $subscriptionId = $(az account show --query id -o tsv)
    $resourceGroupName = $(az keyvault show --name $KeyVaultName --query resourceGroup -o tsv)
    $keyVaultId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.KeyVault/vaults/$KeyVaultName"

    if ($AdminContributorRole) {
        $roles = @("Key Vault Administrator", "Key Vault Contributor")
    }
    else {
        $roles = @("Key Vault Secrets User")
    }

    $roleAssignmentExists = $false

    foreach ($role in $roles) {
        try {
            $existingRoleAssignment = az role assignment list `
                --assignee $ApplicationClientId `
                --role $role `
                --scope $keyVaultId `
                --query [].id `
                -o tsv

            if ($existingRoleAssignment) {
                Write-Host "RBAC role '$role' for SPN '$ApplicationClientId' is already set" -ForegroundColor Green
                $roleAssignmentExists = $true
            }
            else {
                Write-Host "Setting RBAC role '$role' for Key Vault '$KeyVaultName'" -ForegroundColor Yellow
                $retryCount = 5
                $retryInterval = 10

                for ($i = 0; $i -lt $retryCount; $i++) {
                    try {
                        az role assignment create `
                            --assignee $ApplicationClientId `
                            --role $role `
                            --scope $keyVaultId `
                            --output none

                        Write-Host "Set RBAC role '$role' for Key Vault '$KeyVaultName'" -ForegroundColor Green
                        break
                    }
                    catch {
                        Write-Host "Failed to set RBAC role '$role'. Retrying in $retryInterval seconds..." -ForegroundColor Yellow
                        Start-Sleep -Seconds $retryInterval
                    }
                }

                if ($i -eq $retryCount) {
                    Write-Host "Failed to set RBAC role '$role' after multiple attempts" -ForegroundColor Red
                    exit 1
                }
            }
        }
        catch {
            Write-Host "Error checking or setting RBAC role '$role' for SPN '$ApplicationClientId': $_" -ForegroundColor Red
            exit 1
        }
    }

    if (-not $roleAssignmentExists) {
        Write-Host "RBAC roles for SPN '$ApplicationClientId' are set successfully" -ForegroundColor Green
    }
}
catch {
    Write-Host "Error assigning 'User Access Administrator' role to SPN '$ApplicationClientId': $_" -ForegroundColor Red
    exit 1
}
