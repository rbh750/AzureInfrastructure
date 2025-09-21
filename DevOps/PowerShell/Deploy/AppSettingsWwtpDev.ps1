$authClientId = 'b21ca38f-bcc2-4109-853a-c2b47de0633b'
$authClientSecret = 'ePW8Q~imw_bmWf~dKTBSJ5LKdo60iZDBFc5_ycFi'
$tenantId = 'cbc31bc0-a781-4712-809b-3b404c5e19e2'
$subscriptionId = '70147690-87c9-4c3b-9b92-b0470e17a3ab'

# Connect to Azure using a service principal
az login --service-principal -u $authClientId -p $authClientSecret --tenant $tenantId --output none
az account set --subscription $subscriptionId

$Environment = "dev"
$KeyVaultName = "wwtp-dev-kv-229"
$ResourceGroupName = "wwtp-dev-rg-229"

. "$PSScriptRoot/../FindFileByName.ps1"	
$parentDir = Split-Path -Path $PSScriptRoot -Parent 
$rootDir = Split-Path -Path $parentDir -Parent 
$deployAppSettingsScript = Find-FileByName -FileName "DeployAppSettingsController.ps1" -CurrentDirectory $rootDir

# Website.
& $deployAppSettingsScript `
    -AddSettingsToKeyVault $true `
    -IsPublicFnApp $false `
    -IsWebApp $true `
    -AppServiceName "wwtp-dev-web-app-229" `
    -Environment $Environment `
    -keyVaultName $KeyVaultName `
    -NetVersion "v9.0" `
    -ResourceGroupName $ResourceGroupName `
    -SlotName "staging" 

# Fn App public.
& $deployAppSettingsScript `
    -AddSettingsToKeyVault $false `
    -IsPublicFnApp $true `
    -IsWebApp $false `
    -AppServiceName "wwtp-dev-pub-fn-229" `
    -Environment $Environment `
    -keyVaultName $KeyVaultName `
    -NetVersion "v9.0" `
    -ResourceGroupName $ResourceGroupName `
    -SlotName "staging" 

# Fn App private.
& $deployAppSettingsScript `
    -AddSettingsToKeyVault $false `
    -IsPublicFnApp $false `
    -IsWebApp $false `
    -AppServiceName "wwtp-dev-prv-fn-229" `
    -Environment $Environment `
    -keyVaultName $KeyVaultName `
    -NetVersion "v9.0" `
    -ResourceGroupName $ResourceGroupName `
    -SlotName "staging"     