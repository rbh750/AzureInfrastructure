param (
    [bool]$CreateLoginInMasterDb,
    [string]$AdminPas,
    [string]$AdminUser,
    [string]$DatabaseName,  
    [string]$FirewallRuleName,  
    [string]$ServerName,
    [string]$ServerNameAz,
    [string]$ResourceGroupName,    
    [string]$WebPas,
    [string]$WebUser
)

# https://www.sqlservercentral.com/blogs/creating-logins-and-users-in-azure-database

# Function to handle connection errors and create firewall rules
function RetryConnection {
    param (
        [Microsoft.Data.SqlClient.SqlConnection]$connection,
        [string]$resourceGroupName,
        [string]$serverName,
        [string]$firewallRuleName,
        [System.Management.Automation.ErrorRecord]$ex
    )

    $connection.Close()
    $errorMessage = $ex.Exception.Message
    Start-Sleep -Seconds 10

    # Extract the IP address from the error message
    if ($errorMessage -match "Client with IP address '([0-9.]+)' is not allowed to access the server") {
        $extractedIPAddress = $matches[1]

        # Create a firewall rule to allow access from the extracted IP address
        az sql server firewall-rule create `
            --resource-group $resourceGroupName `
            --server $serverName `
            --name $firewallRuleName `
            --start-ip-address $extractedIPAddress `
            --end-ip-address $extractedIPAddress
        | Out-Null

        # Retry the connection
        $connection.Open()
    }
    else {
        throw $ex
    }

    return $connection
}

# For troubleshooting, drop the user in the database first, and then drop the login in the master database
# DROP USER webuser;
# DROP LOGIN webuser;

if ($CreateLoginInMasterDb -eq $true) {
    # The login must be created in the master database once.
    # Create the connection to the master database    
    $sqlCnn = New-Object Microsoft.Data.SqlClient.SqlConnection
    $sqlCnn.ConnectionString = "Server=$ServerNameAz;Database=master;User ID=$AdminUser;Password=$AdminPas"
    try {
        $sqlCnn.Open()
    }
    catch {
        $sqlCnn = RetryConnection `
            -connection $sqlCnn `
            -resourceGroupName $ResourceGroupName `
            -serverName $ServerName `
            -firewallRuleName $FirewallRuleName `
            -ex $_
    }

    # Create login.
    $command = $sqlCnn.CreateCommand()
    $command.CommandText = "CREATE LOGIN [$WebUser] WITH PASSWORD = '$WebPas';"
    $command.ExecuteNonQuery()
    $command.Dispose()

    # Create user in master database (so the user can connect using ssms)
    $command = $sqlCnn.CreateCommand()
    $command.CommandText = "CREATE USER [$WebUser] FOR LOGIN [$WebUser] WITH DEFAULT_SCHEMA = dbo;"
    $command.ExecuteNonQuery()
    $command.Dispose()

    $sqlCnn.Dispose()
}

# Create the user and grant execute permissions
$sqlCnn = New-Object Microsoft.Data.SqlClient.SqlConnection
$sqlCnn.ConnectionString = "Server=$ServerNameAz;Database=$DatabaseName;User ID=$AdminUser;Password=$AdminPas"

try {
    $sqlCnn.Open()
}
catch {
    $sqlCnn = RetryConnection `
        -connection $sqlCnn `
        -resourceGroupName $ResourceGroupName `
        -serverName $ServerName `
        -firewallRuleName $FirewallRuleName `
        -ex $_
}

$command = $sqlCnn.CreateCommand()
$command.CommandText = @"
CREATE USER [$WebUser] FOR LOGIN [$WebUser];
GRANT EXECUTE TO [$WebUser];
"@
    $command.ExecuteNonQuery()
    $command.Dispose()
    $sqlCnn.Dispose()


