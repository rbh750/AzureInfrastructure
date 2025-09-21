$authClientId = 'b21ca38f-bcc2-4109-853a-c2b47de0633b'
$authClientSecret = 'ePW8Q~imw_bmWf~dKTBSJ5LKdo60iZDBFc5_ycFi'
$tenantId = 'cbc31bc0-a781-4712-809b-3b404c5e19e2'
$subscriptionId = '70147690-87c9-4c3b-9b92-b0470e17a3ab'


# Connect to Azure using a service principal
az login --service-principal -u $authClientId -p $authClientSecret --tenant $tenantId --output none
az account set --subscription $subscriptionId

$ShardNumbers = @(1, 61)
$AdminUser = "sysadmin"
$Brand = "wwtp"
$Environment = "dev"
$KeyVaultName = "wwtp-dev-kv-163"
$ResourceGroupName = "wwtp-dev-rg-163"
$WebUser = "webuser"


. "$PSScriptRoot/../FindFileByName.ps1"	
$parentDir = Split-Path -Path $PSScriptRoot -Parent 
$rootDir = Split-Path -Path $parentDir -Parent 
$sqlScript = Find-FileByName -FileName "SqlServer.ps1" -CurrentDirectory $rootDir    
$settingsManager = Find-FileByName -FileName "SettingsManager.ps1" -CurrentDirectory $rootDir
. $settingsManager

& $sqlScript `
    -ShardNumbers $ShardNumbers `
    -AdminUser $AdminUser `
    -Brand $Brand `
    -Environment $Environment `
    -keyVaultName $KeyVaultName `
    -ResourceGroupName $ResourceGroupName `
    -Webuser $WebUser
