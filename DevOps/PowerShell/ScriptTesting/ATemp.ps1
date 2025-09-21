. "$PSScriptRoot/FindFileByName.ps1" 

function Get-ApimPolicyContent {
    param (
        [string]$filePath
    )
    if (Test-Path $filePath) {
        return Get-Content -Path $filePath -Raw
    } else {
        Write-Host "APIM policy file not found: $filePath" -ForegroundColor Red
        Exit 1
    }
}


$parentDir = Split-Path -Path $PSScriptRoot -Parent 
$rootDir = Split-Path -Path $parentDir -Parent 
$apimFile = Find-FileByName -FileName "ApimPolicy.txt" -CurrentDirectory $rootDir
$apimPolicyContent = Get-ApimPolicyContent -filePath $apimFile
$url= 'https://fnap.azurewebsites.net'
$apimPolicyContent = $apimPolicyContent -replace '{{FNAP-URL}}', "`"$url`""

Write-Host $apimPolicyContent