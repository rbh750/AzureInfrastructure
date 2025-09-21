







# # Connect to Azure using a service principal
az login --service-principal -u $authClientId -p $authClientSecret --tenant $tenantId  --output none
az account set --subscription $subscriptionId


$Environment = "Dev"
$KeyVaultName = "tempora-Kv"
$Brand = "wwtp"
$Environment = "Prod"
$ApimPublicApiName = "wwtp-dev-web-public"
$ApimPrivateApiName = "wwtp-dev-web-private"
$ResourceGroupName = "wwtp-dev-141-rg"
$ApimServiceName = "wwtp-dev-141-apim"




. "$PSScriptRoot/../FindFileByName.ps1"	
$parentDir = Split-Path -Path $PSScriptRoot -Parent 
$rootDir = Split-Path -Path $parentDir -Parent 
$apimPrivateFile = Find-FileByName -FileName "ApimPrivatePolicy.xml" -CurrentDirectory $rootDir
$apimPublicFile = Find-FileByName -FileName "ApimPublicPolicy.xml" -CurrentDirectory $rootDir


$apimContext = New-AzApiManagementContext -ResourceGroupName $ResourceGroupName -ServiceName $ApimServiceName 
$fnPrivateNamedValueId = 'private-function-resource-url'
$fnPublicNamedValueId = 'public-function-resource-url'
$privateXSubscriptionNamedValueId = 'private-x-subscription-id'
$publicXSubscriptionNamedValueId = 'public-x-subscription-id'
$ocpSubscriptionHeaderName = 'Ocp-Apim-Subscription-Key'

# Get APIs information
$allApis = az apim api list `
    --resource-group $ResourceGroupName `
    --service-name $ApimServiceName `
    -o json | ConvertFrom-Json

$apis = $allApis | Where-Object { $_.name -eq $ApimPublicApiName -or $_.name -eq $ApimPrivateApiName }    

if ($null -eq $apis) {
    Write-Host "APIs '$ApimPublicApiName' and '$ApimPrivateApiName' not found in APIM service '$ApimServiceName' in resource group '$ResourceGroupName'" -ForegroundColor Red
    Exit 1
}    

$publicApi = $apis | Where-Object { $_.name -eq $ApimPublicApiName }
$privateApi = $apis | Where-Object { $_.name -eq $ApimPrivateApiName }   
$ocpSubscriptionHeaderName = 'Ocp-Apim-Subscription-Key'

function Get-ApimPolicyContent {
    param (
        [string]$filePath
    )
    if (Test-Path $filePath) {
        # Read the content as a raw string
        $content = Get-Content -Path $filePath -Raw
        return $content
    }
    else {
        Write-Host "APIM policy file not found: $filePath" -ForegroundColor Red
        Exit 1
    }
}

# Function to generate IP policy string
function Get-IpPolicy {
    param (
        [string]$ipString
    )
    $ips = $ipString -split ','
    $ipPolicy = "<ip-filter action='allow'>"
    foreach ($ip in $ips) {
        $ipPolicy += "<address>$ip</address>" 
    }
    $ipPolicy += "</ip-filter>"
    return $ipPolicy
}


# Define the origins replacement as an object
if ($Brand.ToLower() -eq 'wwtp') {
    $originsReplacement = [PSCustomObject]@{
        Origins = @(
            "<origin>https://wewantto.party</origin>"
        )
    }
}

# Convert the array of origins into a single string, with each origin separated by a newline character
$originsReplacementString = $originsReplacement.Origins -join "`n"

# # Set APIM policy for private API    
# Write-Host "Setting policy for private API" -ForegroundColor Yellow
# $apimPolicyContent = Get-ApimPolicyContent -filePath $apimPrivateFile
# $apimPolicyContent = $apimPolicyContent -replace '<<origins>>', $originsReplacementString
# $apimPolicyContent = $apimPolicyContent -replace '<<FNAP-URL>>', "{{$fnPrivateNamedValueId}}"
# $apimPolicyContent = $apimPolicyContent -replace '<<SUBSCRIPTION-KEY>>', $ocpSubscriptionHeaderName
# Set-AzApiManagementPolicy -Context $apimContext -ApiId $privateApi.name -Policy $apimPolicyContent -Format "rawxml"
# Write-Host "Policy set" -ForegroundColor Green        

# Set APIM policy for public API 
Write-Host "Setting policy for public API" -ForegroundColor Yellow
$apimPolicyContent = Get-ApimPolicyContent -filePath $apimPublicFile

if ($Environment.ToLower() -eq "prod") {
    $apimPolicyContent = $apimPolicyContent -replace '<<origins>>', $originsReplacementString
}
$apimPolicyContent = $apimPolicyContent -replace '<<FNAP-URL>>', "{{$fnPublicNamedValueId}}"
$apimPolicyContent = $apimPolicyContent -replace '<<SUBSCRIPTION-KEY>>', $ocpSubscriptionHeaderName
Set-AzApiManagementPolicy -Context $apimContext -ApiId $publicApi.name -Policy $apimPolicyContent -Format "rawxml"
Write-Host "8 APIM policy set" -ForegroundColor Green