function Find-FileByName {
    param (
        [string]$FileName,
        [string]$CurrentDirectory = (Get-Location).Path
    )

    try {
        # Get all items in the current directory
        $items = Get-ChildItem -Path $CurrentDirectory

        foreach ($item in $items) {
            if ($item.PSIsContainer) {
                Find-FileByName -FileName $FileName -CurrentDirectory $item.FullName
            }
            elseif ($item.Name -eq $FileName) {
                return $item.FullName
            }
        }
    }
    catch {
        Write-Error "An error occurred: $_"
    }
}

function Find-DirectoryByName {
    param (
        [string]$DirectoryName,
        [string]$CurrentDirectory = (Get-Location).Path
    )

    try {
        # Get all items in the current directory
        $items = Get-ChildItem -Path $CurrentDirectory

        foreach ($item in $items) {
            if ($item.PSIsContainer) {
                if ($item.Name -eq $DirectoryName) {
                    return $item.FullName
                }
                else {
                    $result = Find-DirectoryByName -DirectoryName $DirectoryName -CurrentDirectory $item.FullName
                    if ($result) {
                        return $result
                    }
                }
            }
        }
    }
    catch {
        Write-Error "An error occurred: $_"
    }
}