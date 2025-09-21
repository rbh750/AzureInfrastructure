param (
    [int[]]$ShardNumbers,
    [string]$AdminUser,
    [string]$Brand,
    [string]$Environment,    
    [string]$keyVaultName,      
    [string]$ResourceGroupName,
    [string]$Webuser
)

function SecurePassword {
    [CmdletBinding()]
    param (
        [int]$Length = 32,
        [bool]$Uppercase = $true,
        [bool]$Lowercase = $true,
        [bool]$Numbers = $true,
        [bool]$Symbols = $true
    )

    $characterSet = @()
    $passwordComponents = @()

    if ($Uppercase) {
        $uppercaseChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".ToCharArray()
        $characterSet += $uppercaseChars
        $passwordComponents += (Get-Random -InputObject $uppercaseChars)
    }

    if ($Lowercase) {
        $lowercaseChars = "abcdefghijklmnopqrstuvwxyz".ToCharArray()
        $characterSet += $lowercaseChars
        $passwordComponents += (Get-Random -InputObject $lowercaseChars)
    }

    if ($Numbers) {
        $numberChars = "0123456789".ToCharArray()
        $characterSet += $numberChars
        $passwordComponents += (Get-Random -InputObject $numberChars)
    }

    if ($Symbols) {
        $SymbolChars = "!@#%^*".ToCharArray()
        $characterSet += $SymbolChars
        $passwordComponents += (Get-Random -InputObject $SymbolChars)
    }

    if (!$characterSet) {
        Write-Error "At least one character set must be selected."
        return
    }

    # Fill the rest of the password length with random characters
    while ($passwordComponents.Length -lt $Length) {
        $passwordComponents += (Get-Random -InputObject $characterSet)
    }

    # Shuffle the password components to ensure randomness
    $shuffledPassword = ($passwordComponents | Get-Random -Count $passwordComponents.Length) -join ''

    # Trim the password to the desired length if it's longer due to required characters
    $finalPassword = $shuffledPassword.Substring(0, $Length)

    return $finalPassword
}
function SetConnectionString {
    param (
        [string]$ConnectionString,
        [string]$Username,
        [string]$Pswrd
    )

    $updatedConnectionString = $ConnectionString -replace "<username>", $Username -replace "<password>", $Pswrd
    return $updatedConnectionString
}
function ShardConnectionString {
    param (
        [string]$Username,
        [string]$Pswrd
    )

    return "User ID=$Username;Password=$Pswrd;SecurityInfo=False;MultipleActiveResultSets=False;Encrypt=true;TrustServerCertificate=False;Connection Timeout=30;"
}


# Check if the last version of Az.Websites module is installed.
$latestVersion = (Find-Module -Name SqlServer).Version
$installedVersion = Get-InstalledModule -Name SqlServer -ErrorAction SilentlyContinue

if ($installedVersion -and $installedVersion.Version -ne $latestVersion) {
    Write-Host "Updating SqlServer module to the latest version: $latestVersion" -ForegroundColor Yellow
    if ($env:BUILD_BUILDID) {
        Install-Module -Name SqlServer -Scope CurrentUser -Force
    }
    else {
        Install-Module -Name SqlServer -Scope AllUsers -Force
    }
}

if (-not (Get-Module -Name SqlServer)) {
    Write-Host "Importing SqlServer module" -ForegroundColor Yellow
    Import-Module SqlServer
}

try {
    . "$PSScriptRoot/FindFileByName.ps1"
    $rootDir = Split-Path -Path $parentDir -Parent 
    $serverBicepFile = Find-FileByName -FileName "SqlServer.bicep" -CurrentDirectory $rootDir 
    $datbaseBicepFile = Find-FileByName -FileName "SqlDatabase.bicep" -CurrentDirectory $rootDir 
    $keyVaultSecretsScript = Find-FileByName -FileName "KeyVaultSecrets.ps1" -CurrentDirectory $rootDir
    $settingsManager = Find-FileByName -FileName "SettingsManager.ps1" -CurrentDirectory $rootDir
    . $settingsManager
    $settingsFilePath = Find-FileByName -FileName "SettingsIndex.xlsx" -CurrentDirectory $rootDir     
    $createWebuserScript = Find-FileByName -FileName "SqlSeverCreateWebUser.ps1" -CurrentDirectory $rootDir

    $initialAdminPassword = 'D3v0sP@asword'
    $firewallRuleName = "DevOpsIp"

    # 1 Create SQL server. Use a temp assword as the bicep template is not adding the generated random password property.
    Write-Host "Deploying SQL server" -ForegroundColor Yellow
    $serverName = $Brand + "-" + $Environment + "-" + "sql-server"
    $azSever = "tcp:$serverName.database.windows.net,1433"

    # For the SQL Server and the Shard Map Manager.
    $adminPassword = SecurePassword `
        -Length 32 `
        -Uppercase $true `
        -Lowercase $true `
        -Numbers $true `
        -Symbols $true    

    # For the routing and shards.
    $webPassword = SecurePassword `
        -Length 32 `
        -Uppercase $true `
        -Lowercase $true `
        -Numbers $true `
        -Symbols $true    

    # 1 Create the SQL server
    az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file $serverBicepFile `
        --parameters `
        serverName=$serverName `
        adminUser=$AdminUser `
        adminPassword=$initialAdminPassword `
        --query properties.outputs `
        --output json | Out-String
    
    # 2 Shard map manager db
    Write-Host "Deploying shard map manger database" -ForegroundColor Yellow
    $dbShardMapManager = $Brand + "-" + "shard-map-manager"
    az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file $datbaseBicepFile `
        --parameters `
        databaseName=$dbShardMapManager `
        serverName=$serverName `
        serviceTier='Basic' `
        --query properties.outputs `
        --output json | Out-String

    # 2.2 Get the shard map manger connection string.
    $shardMapCnn = az sql db show-connection-string `
        --server $ServerName `
        --name $dbShardMapManager `
        --client ado.net `
        --output tsv

    $shardMapCnn = SetConnectionString `
        -ConnectionString $shardMapCnn `
        -Username $AdminUser `
        -Pswrd $adminPassword   

    # 3 Routing db
    Write-Host "Deploying routing database" -ForegroundColor Yellow
    $dbRoutingName = $Brand + "-" + "routing"
    az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file $datbaseBicepFile `
        --parameters `
        databaseName=$dbRoutingName `
        serverName=$serverName `
        serviceTier='Basic' `
        --query properties.outputs `
        --output json | Out-String

    # 3.1 Create the web user in the routing database.
    Start-Sleep -Seconds 30
    & $createWebuserScript `
        -AdminPas $initialAdminPassword `
        -AdminUser $AdminUser `
        -CreateLoginInMasterDb $true `
        -DatabaseName $dbRoutingName `
        -FirewallRuleName $firewallRuleName + 0 `
        -ResourceGroupName $ResourceGroupName `
        -ServerName $serverName `
        -ServerNameAz $azSever `
        -WebPas $webPassword `
        -WebUser $Webuser
   
    # The Azure:Shards setting consists of the routing and shards database connection strings. 
    #     "Shards": [
    #       {
    #         "ConnectionString": "User ID=xx;Password=xxx;Trusted_Connection=True;TrustServerCertificate=true;",
    #         "Key": 0,
    #         "Name": "brand-routing"
    #       },
    #       {
    #         "ConnectionString": "",
    #         "Key": 1,
    #         "Name": "brand-s1"
    #       }
    #     ]
    $shardsTable = @{
        Shards = @(
            @{
                ConnectionString = ShardConnectionString -Username $WebUser -Pswrd $webPassword
                Key              = 0
                Name             = $dbRoutingName
            }
        )
    }
    
    # 4 Shrd dbs.
    foreach ($shard in $SqlShardNumbers) {
        $dbName = "$Brand-s$shard"
        Write-Host "Deploying shard '$shard' database" -ForegroundColor Yellow

        # 4.1 Create shard database.
        az deployment group create `
            --resource-group $ResourceGroupName `
            --template-file $datbaseBicepFile `
            --parameters `
            databaseName=$dbName `
            serverName=$serverName `
            serviceTier='Basic' `
            --query properties.outputs `
            --output json | Out-String

        # 4.2 Create the web user in the shard database.
        Start-Sleep -Seconds 30
        & $createWebuserScript `
            -AdminPas $initialAdminPassword `
            -AdminUser $AdminUser `
            -CreateLoginInMasterDb $false `
            -DatabaseName $dbName `
            -FirewallRuleName $firewallRuleName + $shard `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $serverName `
            -ServerNameAz $azSever `
            -WebPas $webPassword `
            -WebUser $Webuser

        # 4.4 Add database connection string to the Azure:Shards settings.
        $shardsTable["Shards"] += @(
            @{
                ConnectionString = ShardConnectionString -Username $WebUser -Pswrd $webPassword
                Key              = $shard
                Name             = $dbName 
            }
        )
    }       

    # 5 Update the server admin password with a random generated password and disable public access.
    az sql server update `
        --name $serverName `
        --resource-group $ResourceGroupName `
        --admin-password $adminPassword

    # 6 Delete the firewall rule.
    $firewallRules = az sql server firewall-rule list `
        --resource-group $ResourceGroupName `
        --server $ServerName | ConvertFrom-Json

    foreach ($rule in $firewallRules) {
        $ruleName = $rule.name
        az sql server firewall-rule delete `
            --resource-group $ResourceGroupName `
            --server $ServerName `
            --name $ruleName
    }    

    # 7 Add credentials to key vault and Excel file.

    # Save the admin password to the key vault
    & $keyVaultSecretsScript `
        -keyVaultName $keyVaultName `
        -secretName 'SqlAdminPassword' `
        -secretValue $adminPassword  

    # # Save the web password to the key vault
    # & $keyVaultSecretsScript `
    #     -keyVaultName $keyVaultName `
    #     -secretName 'SqlWebPassword' `
    #     -secretValue $webPassword

    # Get the shard map manager secret name.
    $shardMapCnnSettingPath = "Azure:CommandService:ShardMapManagerConnectionString"
    $shardMapCnnSecretName = GetKeyVaultSecretKeyName `
        -Environment $Environment `
        -SettingPath $shardMapCnnSettingPath `
        -ExcelFilePath $settingsFilePath        

    # Save the shard map manager connection string to the key vault.
    & $keyVaultSecretsScript `
        -keyVaultName $keyVaultName `
        -secretName $shardMapCnnSecretName `
        -secretValue $shardMapCnn

    # Get the Shards secret name. 
    $shardsSettingPath = 'Azure:Shards'
    $shardsSecretName = GetKeyVaultSecretKeyName `
        -Environment $Environment `
        -SettingPath $shardsSettingPath `
        -ExcelFilePath $settingsFilePath    

    # Save Azure:Shards to the key vault
    $shardsJsonValue = $shardsTable | ConvertTo-Json -Compress

    & $keyVaultSecretsScript `
        -keyVaultName $keyVaultName `
        -secretName $shardsSecretName `
        -secretValue $shardsJsonValue
        
    # Save the shard map manager connection string to Excel file.
    SetSettingValue `
        -Environment $Environment `
        -SettingPath $shardMapCnnSettingPath `
        -SettingValue  $shardMapCnn `
        -ExcelFilePath $settingsFilePath    

    # Save Azure:Shards to Excel file.
    SetSettingValue `
        -Environment $Environment `
        -SettingPath $shardsSettingPath `
        -SettingValue $shardsJsonValue `
        -ExcelFilePath $settingsFilePath    
    
}
catch {
    Write-Host "Failed to process SQL Server" -ForegroundColor Red
    Write-Host "File SqlServer.ps1, line Number: $($_.InvocationInfo.ScriptLineNumber)"
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host "Stack Trace: $($_.Exception.StackTrace)"
    Exit 1
}