param (
    [string]$keyVaultName,
    [string]$authClientId
)

try {
    # Set RBAC roles for the Key Vault
    Write-Host "Checking if RBAC roles for Key Vault '$keyVaultName' are already set for SPN '$authClientId'" -ForegroundColor Yellow

    $subscriptionId = $(az account show --query id -o tsv)
    $resourceGroupName = $(az keyvault show --name $keyVaultName --query resourceGroup -o tsv)
    $keyVaultId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.KeyVault/vaults/$keyVaultName"

    $roles = @("Key Vault Administrator", "Key Vault Contributor")
    $roleAssignmentExists = $false

    foreach ($role in $roles) {
        try {
            $existingRoleAssignment = az role assignment list `
                --assignee $authClientId `
                --role $role `
                --scope $keyVaultId `
                --query [].id `
                -o tsv

            if ($existingRoleAssignment) {
                Write-Host "RBAC role '$role' for SPN '$authClientId' is already set" -ForegroundColor Green
                $roleAssignmentExists = $true
            } else {
                Write-Host "Setting RBAC role '$role' for Key Vault '$keyVaultName'" -ForegroundColor Yellow
                $retryCount = 5
                $retryInterval = 10

                for ($i = 0; $i -lt $retryCount; $i++) {
                    try {
                        az role assignment create `
                            --assignee $authClientId `
                            --role $role `
                            --scope $keyVaultId

                        Write-Host "Set RBAC role '$role' for Key Vault '$keyVaultName'" -ForegroundColor Green
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
            Write-Host "Error checking or setting RBAC role '$role' for SPN '$authClientId': $_" -ForegroundColor Red
            exit 1
        }
    }

    if (-not $roleAssignmentExists) {
        Write-Host "RBAC roles for SPN '$authClientId' are set successfully" -ForegroundColor Green
    }
}
catch {
    Write-Host "Error assigning 'User Access Administrator' role to SPN '$authClientId': $_" -ForegroundColor Red
    exit 1
}

