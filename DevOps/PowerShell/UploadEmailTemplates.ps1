param (
    [string]$Brand,
    [string]$ContainerName,
    [string]$ResourceGroupName,
    [string]$StorageAccountName
)


# Convert the first letter of $Brand to upper case
# `^`: This is an anchor that matches the start of a string.
# `(.)`: This is a capturing group that matches any single character (except newline characters).
$Brand = $Brand -replace '^(.)', { $_.Value.ToUpper() }

# Define the directories
$parentDir = Split-Path -Path $PSScriptRoot -Parent
$rootDir = Split-Path -Path $parentDir -Parent
$emailFolder = Find-DirectoryByName -DirectoryName "EmailTemplates" -CurrentDirectory $rootDir

$brandSubDir = $emailFolder + "\" + ($Brand) + "\"

Write-Host "Uploading email templates" -ForegroundColor Yellow

try {
    # Function to update img src attributes in HTML files and return a MemoryStream with the file content
    function Update-ImgSrc {
        param (
            [string]$FilePath,
            [string]$StorageAccountName,
            [string]$ContainerName
        )

        # Read the content of the HTML file
        $content = Get-Content -Path $FilePath -Raw

        # Use regex to find and replace img src attributes
        $regex = '(<<[^"]+>>)'
        $mtchs = [regex]::Matches($content, $regex)

        if ( $mtchs.Count -gt 0 ) {
            foreach ($match in $mtchs) {
                $blobName = $match.Value `
                    -replace '<<', '' `
                    -replace '>>', ''
                $src = "https://$StorageAccountName.blob.core.windows.net/$ContainerName/$blobName"
                $content  = $content -replace $match.Value, $src
            }

        }
        else {
            Write-Host "Failed to upload email templates. Cannot find logo or footer image file." -ForegroundColor Red
            Exit 1
        }
        
        # Convert the updated content to a MemoryStream
        $byteArray = [System.Text.Encoding]::UTF8.GetBytes($content )
        $memoryStream = New-Object System.IO.MemoryStream
        $memoryStream.Write($byteArray, 0, $byteArray.Length)
        $memoryStream.Position = 0

        return $memoryStream
    }

    # Get the storage account key
    $storageAccountKey = az storage account keys list `
        --resource-group $ResourceGroupName `
        --account-name $StorageAccountName `
        --query "[0].value" `
        --output tsv

    # Update img src attributes in each HTML file and upload the MemoryStream to the storage account.
    Get-ChildItem -Path $brandSubDir -Recurse -Filter "*.html" | ForEach-Object {
        $htmlFile = $_

        $memoryStream = Update-ImgSrc `
            -FilePath $htmlFile.FullName `
            -storageAccountName $StorageAccountName `
            -containerName $ContainerName

        Write-Host "Updated img src in file: $($htmlFile.FullName)" -ForegroundColor Green

        # Upload the MemoryStream to the storage account
        $blobName = [System.IO.Path]::GetFileName($htmlFile.FullName)

        # Creates a uniquely named, empty temporary file on disk and returns the full path of that file.
        $tempFilePath = [System.IO.Path]::GetTempFileName()

        $memoryStream.Position = 0
        $reader = New-Object System.IO.StreamReader($memoryStream)
        $content  = $reader.ReadToEnd()
        Set-Content -Path $tempFilePath -Value $content 

        az storage blob upload `
            --account-name $StorageAccountName `
            --account-key $storageAccountKey `
            --container-name $ContainerName `
            --file $tempFilePath `
            --name $blobName `
            --overwrite

        # Remove the temporary file
        Remove-Item -Path $tempFilePath
    }

    # Upload image files.
    Get-ChildItem -Path $brandSubDir -File -Recurse -Include *.jpg, *.jpeg, *.png, *.gif | ForEach-Object {
        $localFilePath = $_.FullName
        $BlobName = $_.Name
        az storage blob upload `
            --file $localFilePath `
            --container-name $ContainerName `
            --name $BlobName `
            --account-name $StorageAccountName `
            --account-key $storageAccountKey `
            --overwrite
    }
}
catch {
    Write-Host "Failed to upload email templates" -ForegroundColor Red
    Write-Host "File UploadEmailTemplates.ps1, line Number: $($_.InvocationInfo.ScriptLineNumber)"
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host "Stack Trace: $($_.Exception.StackTrace)"
    Exit 1
}

Write-Host "Email templates uploaded" -ForegroundColor Green