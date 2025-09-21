$subscriptionId = "70147690-87c9-4c3b-9b92-b0470e17a3ab"
$keyVaultName = "wwtp-dev1-kv"
$location = "westus"
$assignee = "b21ca38f-bcc2-4109-853a-c2b47de0633b"
$tenantId = "cbc31bc0-a781-4712-809b-3b404c5e19e2"
$clientId = "b21ca38f-bcc2-4109-853a-c2b47de0633b"
$clientSecret = "47w8Q~RsaZYRSzNnI229Ikup_YR~E-9r_kEzvcrk"
$resourceGroupName = "wwtp-dev-rg"
$deleteKeyVault = $true
$createKeyVault = $false
$addSecrets = $false

# Log in to Azure using the service principal
az login --service-principal --username $clientId --password $clientSecret --tenant $tenantId

if ($deleteKeyVault) {
    try {
        # Check if the Key Vault exists
        $keyVault = az keyvault show --name $keyVaultName --resource-group $resourceGroupName --query "id" -o tsv

        if ($keyVault) {
            Write-Host "Deleting Key Vault '$keyVaultName'..." -ForegroundColor Yellow
            az keyvault delete --name $keyVaultName --resource-group $resourceGroupName
            Write-Host "Deleted Key Vault '$keyVaultName'" -ForegroundColor Green

            Write-Host "Purging Key Vault '$keyVaultName'..." -ForegroundColor Yellow
            az keyvault purge --name $keyVaultName
            Write-Host "Purged Key Vault '$keyVaultName'" -ForegroundColor Green
        }
        else {
            Write-Host "Key Vault '$keyVaultName' does not exist in resource group '$resourceGroupName'" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Error deleting or purging Key Vault '$keyVaultName': $_" -ForegroundColor Red
        exit 1
    }
    exit 0
}

# Set the subscription context
az account set --subscription $subscriptionId

if ($createKeyVault) {
    # Create the Key Vault
    az keyvault create --name $keyVaultName --resource-group $resourceGroupName --location $location

    # Call KeyVaultRbacRoles.ps1
    $keyVaultRbacRolesScript = Join-Path -Path (Split-Path -Path $PSScriptRoot) -ChildPath "KeyVaultRbacRoles.ps1"
    & $keyVaultRbacRolesScript -keyVaultName $keyVaultName -authClientId $clientId -AdminContributorRole $true

    # Get the Key Vault resource ID
    $keyVaultResourceId = az keyvault show --name $keyVaultName --query id -o tsv

    # List role assignments for the assignee
    $roleAssignments = az role assignment list --scope $keyVaultResourceId --assignee $assignee --query "[].roleDefinitionName" -o tsv

    # Convert role assignments output to an array
    $roleAssignmentsArray = $roleAssignments -split "`n"

    # Define required roles
    $requiredRoles = @("Key Vault Administrator", "Key Vault Contributor", "Key Vault Secrets Officer")

    # Check if the assignee has required roles
    foreach ($role in $requiredRoles) {
        if ($roleAssignmentsArray -contains $role) {
            Write-Output "$assignee has the $role role."
        }
        else {
            Write-Output "$assignee does not have the $role role."
        }
    }
}

if ($addSecrets) {
    # Define the parameters to pass to KeyVaultSecrets.ps1
    $secretName = 'test'
    $secretValue = '123'

    # Construct the full path to KeyVaultSecrets.ps1
    $keyVaultSecretsScript = Join-Path -Path (Split-Path -Path $PSScriptRoot) -ChildPath "KeyVaultSecrets.ps1"

    # Call KeyVaultSecrets.ps1 with the specified parameters
    & $keyVaultSecretsScript -keyVaultName $keyVaultName -secretName $secretName -secretValue $secretValue

    # Get the list of secrets
    $secrets = az keyvault secret list --vault-name $keyVaultName --query "[].id" -o tsv

    foreach ($secretId in $secrets) {
        # Get the value of each secret
        $secretValue = az keyvault secret show --id $secretId --query "value" -o tsv
        Write-Output "Secret ID: $secretId"
        Write-Output "Secret Value: $secretValue"
        Write-Output ""
    }
}

