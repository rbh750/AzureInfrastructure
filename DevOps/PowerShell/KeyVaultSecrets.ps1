param (
    [string]$keyVaultName,
    [string]$secretName,
    [string]$secretValue
)

try {
    # Check if the secret exists
    $secretOutput = az keyvault secret show `
        --vault-name $keyVaultName `
        --name $secretName `
        --output json 2>$null

    if ($LASTEXITCODE -ne 0) {
        $secret = $null
    }
    else {
        $secret = ($secretOutput | ConvertFrom-Json).id
    }

    # Several special characters can cause issues in Azure CLI commands, especially when used as argument values.
    # To avoid issues, use the = sign instead of a space when using the --value parameter.

    if ($secret) {
        Write-Host "Secret '$secretName' exists. Adding a new version and invalidating previous versions..." -ForegroundColor Yellow

        # Add a new version of the secret
        $newSecretOutput = az keyvault secret set `
            --vault-name $keyVaultName `
            --name $secretName `
            --value=$secretValue `
            --output json

        $newSecret = ($newSecretOutput | ConvertFrom-Json).id

        # List all versions of the secret
        $secretVersionsOutput = az keyvault secret list-versions `
            --vault-name $keyVaultName `
            --name $secretName `
            --output json

        $secretVersions = ($secretVersionsOutput | ConvertFrom-Json) | ForEach-Object { $_.id }

        # Invalidate all previous versions except the new one
        foreach ($version in $secretVersions) {
            if ($version -ne $newSecret) {
                az keyvault secret set-attributes `
                    --id $version `
                    --enabled false `
                    --output json >$null
                Start-Sleep -Seconds 1
            }
        }

        Write-Host "Added a new version and invalidated all previous versions of the secret '$secretName'" -ForegroundColor Green
    }
    else {
        # Check if the secret exists in a deleted state
        $deletedSecretOutput = az keyvault secret list-deleted `
            --vault-name $keyVaultName `
            --output json

        $deletedSecret = ($deletedSecretOutput | ConvertFrom-Json) | Where-Object { $_.name -eq $secretName } | Select-Object -ExpandProperty id

        if ($deletedSecret) {
            Write-Host "Secret '$secretName' exists in a deleted state. Restoring and invalidating it..." -ForegroundColor Yellow

            # Restore the deleted secret
            az keyvault secret recover `
                --vault-name $keyVaultName `
                --name $secretName `
                --output json >$null

            # Invalidate the restored secret
            az keyvault secret set-attributes `
                --vault-name $keyVaultName `
                --name $secretName `
                --enabled false `
                --output json >$null

            # Add a new version of the secret
            $newSecretOutput = az keyvault secret set `
                --vault-name $keyVaultName `
                --name $secretName `
                --value=$secretValue `
                --output json

            $newSecret = ($newSecretOutput | ConvertFrom-Json).id

            # List all versions of the secret
            $secretVersionsOutput = az keyvault secret list-versions `
                --vault-name $keyVaultName `
                --name $secretName `
                --output json

            $secretVersions = ($secretVersionsOutput | ConvertFrom-Json) | ForEach-Object { $_.id }

            # Invalidate all previous versions except the new one
            foreach ($version in $secretVersions) {
                if ($version -ne $newSecret) {
                    az keyvault secret set-attributes `
                        --id $version `
                        --enabled false `
                        --value=$secretValue >$null
                    Start-Sleep -Seconds 1
                }
            }

            Write-Host "Restored, invalidated, and added a new version of the secret '$secretName'" -ForegroundColor Green
        }
        else {
            # Add the secret to the Key Vault as a new secret
            Write-Host "Adding secret $secretName to the Key Vault" -ForegroundColor Green

            az keyvault secret set `
                --vault-name $keyVaultName `
                --name $secretName `
                --value=$secretValue >$null
        }
    }
}
catch {
    Write-Host "Failed to manage the secret in the Key Vault" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor Red
    exit 1
}
