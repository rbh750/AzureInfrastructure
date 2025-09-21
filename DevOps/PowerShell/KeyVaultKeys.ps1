param (
    [string]$keyVaultName,
    [string]$keyName,
    [string]$keyType = "RSA",
    [int]$keySize = 2048
)

try {
    # Check if the key exists
    $keyOutput = az keyvault key show `
        --vault-name $keyVaultName `
        --name $keyName `
        --output json

    if ($LASTEXITCODE -ne 0) {
        $key = $null
    }
    else {
        $key = ($keyOutput | ConvertFrom-Json).key.kid
    }

    if ($key) {
        Write-Host "Key '$keyName' exists. Adding a new version and invalidating previous versions..." -ForegroundColor Yellow

        # Add a new version of the key
        $newKeyOutput = az keyvault key create `
            --vault-name $keyVaultName `
            --name $keyName `
            --kty $keyType `
            --size $keySize `
            --output json

        $newKey = ($newKeyOutput | ConvertFrom-Json).key.kid

        # List all versions of the key
        $keyVersionsOutput = az keyvault key list-versions `
            --vault-name $keyVaultName `
            --name $keyName `
            --output json

        $keyVersions = ($keyVersionsOutput | ConvertFrom-Json) | ForEach-Object { $_.key.kid }

        # Invalidate all previous versions except the new one
        foreach ($version in $keyVersions) {
            if ($version -ne $newKey) {
                az keyvault key update-attributes `
                    --id $version `
                    --enabled false
            }
        }

        Write-Host "Added a new version and invalidated all previous versions of the key '$keyName'" -ForegroundColor Green
    } else {
        # Check if the key exists in a deleted state
        $deletedKeyOutput = az keyvault key list-deleted `
            --vault-name $keyVaultName `
            --output json

        $deletedKey = ($deletedKeyOutput | ConvertFrom-Json) | Where-Object { $_.name -eq $keyName } | Select-Object -ExpandProperty key.kid

        if ($deletedKey) {
            Write-Host "Key '$keyName' exists in a deleted state. Restoring and invalidating it..." -ForegroundColor Yellow

            # Restore the deleted key
            az keyvault key recover `
                --vault-name $keyVaultName `
                --name $keyName

            # Invalidate the restored key
            az keyvault key update-attributes `
                --vault-name $keyVaultName `
                --name $keyName `
                --enabled false

            # Add a new version of the key
            $newKeyOutput = az keyvault key create `
                --vault-name $keyVaultName `
                --name $keyName `
                --kty $keyType `
                --size $keySize `
                --output json

            $newKey = ($newKeyOutput | ConvertFrom-Json).key.kid

            # List all versions of the key
            $keyVersionsOutput = az keyvault key list-versions `
                --vault-name $keyVaultName `
                --name $keyName `
                --output json

            $keyVersions = ($keyVersionsOutput | ConvertFrom-Json) | ForEach-Object { $_.key.kid }

            # Invalidate all previous versions except the new one
            foreach ($version in $keyVersions) {
                if ($version -ne $newKey) {
                    az keyvault key update-attributes `
                        --id $version `
                        --enabled false
                }
            }

            Write-Host "Restored, invalidated, and added a new version of the key '$keyName'" -ForegroundColor Green
        } else {
            # Add the key to the Key Vault as a new key
            az keyvault key create `
                --vault-name $keyVaultName `
                --name $keyName `
                --kty $keyType `
                --size $keySize

            Write-Host "Added the key to the Key Vault as a new key" -ForegroundColor Green
        }
    }
}
catch {
    Write-Host "Failed to manage the key in the Key Vault" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
