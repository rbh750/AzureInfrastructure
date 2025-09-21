# The purpose of this script is to automate the assignment of the Azure "Contributor" role to a specified app registration (service principal) 
# for a given App Service within a resource group. 
# This grants the app registration the necessary permissions to deploy, manage, and modify the App Service resources in Azure. 

param (
    [string]$EApClientId, 
    [string]$AppServiceName, 
    [string]$ResourceGroupName
)
       
# Get the resource ID of the App Service
$appServiceResourceId = az webapp show `
    --name $AppServiceName `
    --resource-group $ResourceGroupName `
    --query "id" -o tsv

if (-not $appServiceResourceId) {
    Write-Error "App Service '$AppServiceName' not found in resource group '$ResourceGroupName'."
    exit 1
}

# Assign Contributor role to the app registration for the App Service
az role assignment create `
    --assignee $EApClientId `
    --role "Contributor" `
    --scope $appServiceResourceId

Write-Host "Contributor role assigned to app registration '$EApName' for App Service '$AppServiceName'."