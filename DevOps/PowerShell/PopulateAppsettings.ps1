param (
    [string]$filePath = "E:\GitRepos\Ssmp\Extensions\appSettings.json"
)

function Get-JsonElementNames {
    param (
        [hashtable]$jsonObject,
        [string]$prefix = ""
    )

    foreach ($key in $jsonObject.Keys) {
        $trimmedPrefix = $prefix.Trim()
        $trimmedKey = $key.Trim()
        $newPrefix = if ($trimmedPrefix) { "${trimmedPrefix}:${trimmedKey}" } else { $trimmedKey }

        # Child nodes?
        if ($jsonObject[$key] -is [hashtable]) {
            Get-JsonElementNames -jsonObject $jsonObject[$key] -prefix $newPrefix
        } else {
            Write-Output $newPrefix
        }
    }
}

function ConvertTo-Hashtable {
    param (
        [PSCustomObject]$psObject
    )

    $hashtable = @{}
    foreach ($property in $psObject.PSObject.Properties) {
        if ($property.Value -is [PSCustomObject]) {
            $hashtable[$property.Name] = ConvertTo-Hashtable -psObject $property.Value
        } else {
            $hashtable[$property.Name] = $property.Value
        }
    }
    return $hashtable
}

$jsonContent = Get-Content -Path $filePath -Raw | ConvertFrom-Json
$jsonHashtable = ConvertTo-Hashtable -psObject $jsonContent
Get-JsonElementNames -jsonObject $jsonHashtable