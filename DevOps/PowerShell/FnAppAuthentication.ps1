param (
  [string[]]$AllowedTokenAudiences,
  [string]$ApimServiceName,
  [string]$ClientId,
  [string]$ClientSecretSettingName,
  [string]$FunctionAppName,
  [string]$IssuerUrl,
  [string]$ObjectId,
  [string]$ResourceGroupName,
  [string]$SubscriptionId,
  [string]$Slot
)

# 1 Allowed Token Audiences: only tokens issued to the Function App with the specified Allowed Token Audiences will contain 
# an aud claim referencing the function app, ensuring that only valid tokens intended for the app are accepted.
# 2 Allowed client applications: which clients can send requests to the Fn app.
# 3 Allow requests from specific identities: Only authenticated identities (users, service principals, or managed identities) with the nominated client id can access th Fn app

# Azure REST API url
$uri = "https://management.azure.com/subscriptions/"
$uri += "$SubscriptionId"
$uri += "/resourceGroups/"
$uri += "$ResourceGroupName"
$uri += "/providers/Microsoft.Web/sites/"
$uri += "$FunctionAppName"
if ($Slot -and $Slot -ne "production") {
  $uri += "/slots/$Slot"
}
$uri += "/config/authsettingsV2?api-version=2024-04-01"

# Headers
$accessToken = (az account get-access-token --resource https://management.azure.com/ --query accessToken -o tsv)
$headers = @{
  "Content-Type"  = "application/json"
  "Authorization" = "Bearer $accessToken"
}  

# Uncomment these commands to retrieve the current authSettingsV2 and check the configuration for debugging
# $debug = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers | ConvertTo-Json -Depth 10
# Write-Output $debug

# IMPORTANT: authentication settings and identity providers must be set in two separate requests.

# Create the request body for authentication settings
$authSettingsRequestBody = @{
  properties = @{
    platform = @{
      enabled = $true
    }
    globalValidation = @{
      requireAuthentication = $true
      unauthenticatedClientAction = "Return401"
    }
    httpSettings = @{
      requireHttps = $true
      routes = @{
        apiPrefix = "/.auth"
      }
      forwardProxy = @{
        convention = "NoProxy"
      }
    }
    login = @{
      tokenStore = @{
        enabled = $true
        tokenRefreshExtensionHours = 72
      }
      preserveUrlFragmentsForLogins = $false
      cookieExpiration = @{
        convention = "FixedTime"
        timeToExpiration = "08:00:00"
      }
      nonce = @{
        validateNonce = $true
        nonceExpirationInterval = "00:05:00"
      }
    }
    clearInboundClaimsMapping = $false
  }
}

$jsonAuthSettingsRequestBody = $authSettingsRequestBody | ConvertTo-Json -Depth 10
Invoke-RestMethod -Method Put -Uri $uri -Headers $headers -Body $jsonAuthSettingsRequestBody -StatusCodeVariable statusCode
if ($statusCode -ne 200) {
  Write-Error "$(FunctionAppName) authentication settings request failed with status code $statusCode"
  exit 1
}

Start-Sleep -s 10
$apim = Get-AzApiManagement -ResourceGroupName $ResourceGroupName -Name $ApimServiceName

# Create the request body for identity providers
$identityProvidersRequestBody = @{
  properties = @{
    identityProviders = @{
      azureActiveDirectory = @{
        enabled = $true
        registration = @{
          clientId = $ClientId
          clientSecretSettingName = $ClientSecretSettingName
        }
        validation = @{
          allowedAudiences = @($AllowedTokenAudiences) # 1
          defaultAuthorizationPolicy = @{
            allowedApplications = @($apim.Id) # 2
            allowedPrincipals = @{
              identities = @($ObjectId) # 3
            }
          }
        }
        login = @{
          disableWWWAuthenticate = $false
          loginParameters = @{
            allowImplicitFlow = $true
          }
        }
        issuer = $IssuerUrl
      }
    }
  }
}

$jsonIdentityProvidersRequestBody = $identityProvidersRequestBody | ConvertTo-Json -Depth 10
Invoke-RestMethod -Method Put -Uri $uri -Headers $headers -Body $jsonIdentityProvidersRequestBody -StatusCodeVariable statusCode
if ($statusCode -ne 200) {
  Write-Error "$(FunctionAppName) authentication identity provider request failed with status code $statusCode"
  exit 1
}