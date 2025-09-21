$authClientId = 'b21ca38f-bcc2-4109-853a-c2b47de0633b'
$authClientSecret = 'ePW8Q~imw_bmWf~dKTBSJ5LKdo60iZDBFc5_ycFi'
$tenantId = 'cbc31bc0-a781-4712-809b-3b404c5e19e2'
$subscriptionId = '70147690-87c9-4c3b-9b92-b0470e17a3ab'

# Connect to Azure using a service principal
az login --service-principal -u $authClientId -p $authClientSecret --tenant $tenantId --output none
az account set --subscription $subscriptionId

# Get all app registrations that start with "Wwtp-" except "www-proto"
$appRegistrations = az ad app list `
    --filter "startswith(displayName, 'Wwtp-')" `
    --query "[?displayName!='wwtp-proto']" `
    --output json | ConvertFrom-Json

# Loop through and delete each app registration
foreach ($app in $appRegistrations) {
    Write-Host "Deleting app registration: $($app.displayName)" -ForegroundColor Yellow
    az ad app delete --id $app.appId
}

Write-Host "Completed removing app registrations." -ForegroundColor Green