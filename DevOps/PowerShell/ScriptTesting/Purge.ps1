# # Log in to Azure
# az account clear
# az config set core.enable_broker_on_windows=false
# az login

# # List all deleted key vaults using Azure CLI and convert the output to PowerShell objects
# $deletedKeyVaults = az keyvault list-deleted --query "[].{Name:name, Location:properties.location}" -o json | ConvertFrom-Json

# # Loop through each deleted key vault and purge it using Azure CLI
# foreach ($keyVault in $deletedKeyVaults) {
#     Write-Host "Purging key vault: $($keyVault.Name) in location: $($keyVault.Location)"
#     az keyvault purge --name $keyVault.Name --location $keyVault.Location
# }

# # List all deleted resources using Azure CLI and convert the output to PowerShell objects
# $deletedResources = az resource list --query "[?properties.provisioningState=='Deleted']" -o json | ConvertFrom-Json

# # Filter for deleted API Management instances
# $deletedApims = $deletedResources | Where-Object { $_.type -eq 'Microsoft.ApiManagement/service' }

# # Loop through each deleted API Management instance and purge it using Azure CLI
# foreach ($apim in $deletedApims) {
#     Write-Host "Purging APIM instance: $($apim.name) in location: $($apim.location)"
#     az resource delete --ids $apim.id --force
# }

# Log in to Azure
az account clear
az config set core.enable_broker_on_windows=false
az login


Write-Host "Purging key vaults..." -ForegroundColor Yellow

# List all deleted key vaults using Azure CLI and convert the output to PowerShell objects
$deletedKeyVaults = az keyvault list-deleted --query "[].{Name:name, Location:properties.location}" -o json | ConvertFrom-Json

# Purge deleted key vaults in parallel
$deletedKeyVaults | ForEach-Object {
    Start-Job -ScriptBlock {
        param($Name, $Location)
        az keyvault purge --name $Name --location $Location
    } -ArgumentList $_.Name, $_.Location
} | Wait-Job | ForEach-Object {
    Write-Host "Purged key vault: $($_.Name)"
    Remove-Job $_.Id
}

# List all deleted resources using Azure CLI and convert the output to PowerShell objects
$deletedResources = az resource list --query "[?properties.provisioningState=='Deleted']" -o json | ConvertFrom-Json

# Filter for deleted API Management instances
$deletedApims = $deletedResources | Where-Object { $_.type -eq 'Microsoft.ApiManagement/service' }

# Purge deleted API Management instances in parallel
$deletedApims | ForEach-Object {
    Start-Job -ScriptBlock {
        param($Id)
        az resource delete --ids $Id --force
    } -ArgumentList $_.id
} | Wait-Job | ForEach-Object {
    Write-Host "Purged APIM instance: $($_.Name)"
    Remove-Job $_.Id
}

# Purge APIMs in 'ServiceAlreadyExistsInSoftDeletedState' state
Write-Host "Purging APIM..." -ForegroundColor Yellow

# List all soft-deleted APIMs using Azure CLI and convert the output to PowerShell objects
$softDeletedApims = az resource list --query "[?type=='Microsoft.ApiManagement/service' && properties.provisioningState && contains(properties.provisioningState, 'ServiceAlreadyExistsInSoftDeletedState')]" -o json | ConvertFrom-Json

# Purge soft-deleted APIMs in parallel
$softDeletedApims | ForEach-Object {
    Start-Job -ScriptBlock {
        param($Id, $Name)
        az resource delete --ids $Id --force
    } -ArgumentList $_.id, $_.name
} | Wait-Job | ForEach-Object {
    Write-Host "Purged APIM instance in ServiceAlreadyExistsInSoftDeletedState: $($_.Name)"
    Remove-Job $_.Id
}

Write-Host "Purging storage accounts..." -ForegroundColor Yellow

# List all soft-deleted storage accounts using Azure CLI and convert the output to PowerShell objects
$deletedStorageAccounts = az storage account list --include-deleted --query "[?deletionTime!=null]" -o json | ConvertFrom-Json

# Purge soft-deleted storage accounts in parallel
$deletedStorageAccounts | ForEach-Object {
    Start-Job -ScriptBlock {
        param($Name, $ResourceGroup)
        az storage account purge --name $Name --resource-group $ResourceGroup
    } -ArgumentList $_.name, $_.resourceGroup
} | Wait-Job | ForEach-Object {
    Write-Host "Purged storage account: $($_.Name)"
    Remove-Job $_.Id
}

Write-Host "Purging Cosmos DB accounts..." -ForegroundColor Yellow

# List all soft-deleted Cosmos DB accounts using Azure CLI and convert the output to PowerShell objects
$deletedCosmosAccounts = az cosmosdb list --include-deleted --query "[?deletionTime!=null]" -o json | ConvertFrom-Json

# Purge soft-deleted Cosmos DB accounts in parallel
$deletedCosmosAccounts | ForEach-Object {
    Start-Job -ScriptBlock {
        param($Name, $ResourceGroup)
        az cosmosdb purge --name $Name --resource-group $ResourceGroup
    } -ArgumentList $_.name, $_.resourceGroup
} | Wait-Job | ForEach-Object {
    Write-Host "Purged Cosmos DB account: $($_.Name)"
    Remove-Job $_.Id
}

