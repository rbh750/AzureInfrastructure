param (
    [string]$functionAppName = "wwtp-dev-fn-consumption",
    [string]$functionAppHostingPlanName = "wwtp-dev-fn-consumption-splan",
    [string]$resourceGroup = "wwtp-dev-rg",
    [string]$functionAppStorageAccountName = "wwtpdevfnconsumptionsto",
    [string]$subscriptionId = "70147690-87c9-4c3b-9b92-b0470e17a3ab"
)

# Dot-source the FindFileByName.ps1 script to include the function
. "$PSScriptRoot/FindFileByName.ps1"

$tenantId = "cbc31bc0-a781-4712-809b-3b404c5e19e2"
$clientId = "b21ca38f-bcc2-4109-853a-c2b47de0633b"
$clientSecret = "47w8Q~RsaZYRSzNnI229Ikup_YR~E-9r_kEzvcrk"

# Log in to Azure using the service principal
az login --service-principal --username $clientId --password $clientSecret --tenant $tenantId

# Set the subscription
az account set --subscription $subscriptionId

$parentDir = Split-Path -Path $PSScriptRoot -Parent 
$rootDir = Split-Path -Path $parentDir -Parent 
$templateFile = Find-FileByName -FileName "FunctionApp.bicep" -CurrentDirectory $rootDir

try {
    $deploymentOutput = az deployment group create `
        --resource-group $resourceGroup `
        --template-file $templateFile  `
        --parameters `
        functionAppName=$functionAppName `
        hostingPlanName=$functionAppHostingPlanName `
        storageAccountName=$functionAppStorageAccountName `
        --query properties.outputs `
        --output json | Out-String    

    Write-Host $deploymentOutput
}
catch {
    Write-Host "An error occurred during the deployment process:" 
    Write-Host $_.Exception.Message
}
 
