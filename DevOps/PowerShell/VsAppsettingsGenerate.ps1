# Generate appsettings.json file an Excel file for Visual Studio.

# Check if the last version of Az.Websites module is installed.
$latestVersion = (Find-Module -Name ImportExcel).Version
$installedVersion = Get-InstalledModule -Name ImportExcel -ErrorAction SilentlyContinue

if ($installedVersion -and $installedVersion.Version -ne $latestVersion) {
    Write-Host "Updating ImportExcel module to the latest version: $latestVersion" -ForegroundColor Yellow
    if ($env:BUILD_BUILDID) {
        Install-Module -Name ImportExcel -Scope CurrentUser -Force
    }
    else {
        Install-Module -Name ImportExcel -Scope AllUsers -Force
    }
}

# Import Excel file
$excelPath = "E:\GitRepos\Ssmp\DevOps\PowerShell\SettingsIndex.xlsx"
$data = Import-Excel -Path $excelPath

# Initialize empty hashtables for each environment
$devSettings = @{}
$prodSettings = @{}

# Function to set nested JSON keys dynamically
function Set-NestedProperty {
    param (
        [Hashtable]$target,
        [String]$path,
        $value
    )

    $keys = $path -split ':'
    $current = $target

    # Given Azure:Apim:PrivateSubscription

    # Iterate through each key except the last one (PrivateSubscription), creating missing (not exist) nested objects.
    for ($i = 0; $i -lt $keys.Length - 1; $i++) {
        $key = $keys[$i]
        if (-not $current[$key]) {
            $current[$key] = @{}  # Creates an empty nested hashtable if missing.
        }
        $current = $current[$key]  # Move deeper into the structure.
    }

    $current[$keys[-1]] = $value # Assign the final value to the deepest key (PrivateSubscription).
}

# Process each row in Excel data
foreach ($row in $data) {
    $addToAppSettings = $row.AddToAppSettings

    # Skip rows where AddToAppSettings is explicitly false
    if ($addToAppSettings -eq $false) {
        continue
    }

    $path = $row.SettingPath
    $value = $row.SettingValue
    $type = $row.SettingType
    $environment = $row.Environment

    # Convert data type
    switch ($type) {
        "int" { $value = [int]$value }
        "double" { $value = [double]$value }
        "string" { 
            if ($null -eq $value) {
                $value = $null
            }
            else {
                $value = [string]$value
            }
        }
    }
    # Detect and parse JSON objects for special cases
    if ($path -eq "Azure:Shards" -and ($value -match "^\{.*\}$")) {
        try {
            $parsedJson = $value | ConvertFrom-Json
            # Transform JSON object into an array format, extracting ConnectionString dynamically
            $newShards = @()
            foreach ($shard in $parsedJson.ShardManager) {
                $newShards += @{
                    "ConnectionString" = $parsedJson.ConnectionString
                    "Key"              = $shard.Key
                    "Name"             = $shard.Name
                }
            }
            $value = $newShards
        }
        catch {
            Write-Host "Failed to parse JSON for $path"
        }
    }

    # Assign nested JSON values based on environment
    if ($environment -eq "Dev") {
        Set-NestedProperty -target $devSettings -path $path -value $value
    }
    elseif ($environment -eq "Prod") {
        Set-NestedProperty -target $prodSettings -path $path -value $value
    }
}

# File paths
$devFile = "D:\appsettings-dev.json"
$prodFile = "D:\appsettings-prod.json"

# Delete existing files before creating new ones
if (Test-Path $devFile) { Remove-Item -Path $devFile -Force }
if (Test-Path $prodFile) { Remove-Item -Path $prodFile -Force }

# Save Dev JSON if it contains settings
if ($devSettings.Count -gt 0) {
    $devJson = $devSettings | ConvertTo-Json -Depth 100
    $devJson | Set-Content -Path $devFile
    Write-Host "appsettings-dev.json generated successfully in D:\"
}

# Save Prod JSON if it contains settings
if ($prodSettings.Count -gt 0) {
    $prodJson = $prodSettings | ConvertTo-Json -Depth 100
    $prodJson | Set-Content -Path $prodFile
    Write-Host "appsettings-prod.json generated successfully in D:\"
}
else {
    Write-Host "No Prod settings found. Skipping appsettings-prod.json creation."
}