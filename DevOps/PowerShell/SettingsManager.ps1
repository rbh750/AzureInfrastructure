function Install-ModuleIfNotInstalled {
    param (
        [string]$ModuleName
    )
    
    # Check if the last version of Az.Websites module is installed.
    $latestVersion = (Find-Module -Name $ModuleName).Version
    $installedVersion = Get-InstalledModule -Name $ModuleName -ErrorAction SilentlyContinue

    if ($installedVersion -and $installedVersion.Version -ne $latestVersion) {
        Write-Host "Updating $ModuleName module to the latest version: $latestVersion" -ForegroundColor Yellow
        if ($env:BUILD_BUILDID) {
            Install-Module -Name $ModuleName -Scope CurrentUser -Force
        }
        else {
            Install-Module -Name $ModuleName -Scope AllUsers -Force
        }
    }

    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Import-Module -Name $ModuleName
    }
}

# Get all application settings in a format compatible with Set-AzWebApp.
# The resulting data will be use to deploy the app settings to the Azure Web App.
function GetAppSettings {
    param (
        [bool]$IsWebApp,
        [string]$Environment,
        [string]$ExcelFilePath,
        [string]$keyVaultName
    )

    # Validate Excel file existence
    if (-not (Test-Path $ExcelFilePath)) {
        Write-Error "Excel file not found at path: $ExcelFilePath"
        return $null
    }

    Install-ModuleIfNotInstalled -ModuleName "ImportExcel"

    # Read the Excel file
    $data = Import-Excel -Path $ExcelFilePath

    # Filter rows based on Environment and App Settings criteria
    $filteredRows = $data | Where-Object {
        $_.Environment.ToLower() -eq $Environment.ToLower() -and
        ($_.AddToAppSettings -eq $true -or [string]::IsNullOrEmpty($_.AddToAppSettings))
    }

    # Initialize a hashtable to store results
    $result = @{}

    foreach ($row in $filteredRows) {
        # Ensure SettingValue is not null
        $settingValue = if ($null -ne $row.SettingValue) { $row.SettingValue } else { "" }

        # If SaveToKeyVault is true, create Key Vault reference
        if ($row.SaveToKeyVault -eq $true -and -not [string]::IsNullOrEmpty($row.SecretKey)) {
            $settingValue = "@Microsoft.KeyVault(SecretUri=https://$keyVaultName.vault.azure.net/secrets/$($row.SecretKey))"
        }

        $settingValue = [string]$settingValue

        # Store in hashtable with structured data
        $result[$row.SettingPath] = @{ Value = $settingValue }
    }

    # Convert the hashtable to a more key value pair format.
    $appSettings = @{}
    foreach ($key in $result.Keys) {
        $appSettings[$key] = $result[$key].Value
    }

    # The AddCommonService.cs extension includes logic to determine whether the application is running locally or in Azure. 
    # This row is automatically injected into the App Service environment variables only during pipeline deployment 
    # (not during local development)."
    if ($IsWebApp) {
        $appSettings["Azure:ExecutionEnvironment"] = "AzureWebApp"
    }
    else {
        $appSettings["Azure:ExecutionEnvironment"] = "AzureFn"
    }
    
    return $appSettings
}

function GetKeyVaultSecretKeyName {
    param (
        [string]$Environment,
        [string]$SettingPath,
        [string]$ExcelFilePath
    )

    Install-ModuleIfNotInstalled -ModuleName "ImportExcel"

    # Read the Excel file
    $data = Import-Excel -Path $ExcelFilePath

    # Find the row that matches the Environment and SettingPath
    $row = $data | Where-Object { $_.Environment.ToLower() -eq $Environment.ToLower() -and $_.SettingPath -eq $SettingPath }

    if ($null -ne $row) {
        return $row.SecretKey
    }
    else {
        Write-Error "No matching row found for Environment: $Environment and SettingPath: $SettingPath"
    }
}

function SetSettingValue {
    param (
        [string]$Environment,
        [string]$SettingPath,
        [string]$SettingValue,
        [string]$ExcelFilePath
    )

    Install-ModuleIfNotInstalled -ModuleName "ImportExcel"

    # Read the Excel file
    $data = Import-Excel -Path $ExcelFilePath

    # Find the row that matches the Environment and SettingPath
    $row = $data | Where-Object { $_.Environment.ToLower() -eq $Environment.ToLower() -and $_.SettingPath -eq $SettingPath }

    if ($null -ne $row) {
        # Check if the SettingValue can be converted to a long integer and has more than 6 digits
        if ($SettingValue -match '^\d+$' -and [long]$SettingValue -gt 999999) {
            $SettingValue = "'$SettingValue"
        }

        # Update the SettingValue
        $row.SettingValue = $SettingValue

        # Export the updated data back to the Excel file
        $data | Export-Excel -Path $ExcelFilePath -WorksheetName "SettingIndex"
    }
    else {
        Write-Error "No matching row found for Environment: $Environment and SettingPath: $SettingPath"
    }
}

function GetSettingValue {
    param (
        [string]$Environment,
        [string]$SettingPath,
        [string]$ExcelFilePath
    )

    Install-ModuleIfNotInstalled -ModuleName "ImportExcel"

    # Read the Excel file
    $data = Import-Excel -Path $ExcelFilePath

    # Find the row that matches the Environment and SettingPath
    $row = $data | Where-Object { $_.Environment.ToLower() -eq $Environment.ToLower() -and $_.SettingPath -eq $SettingPath }

    return $row.SettingValue
}