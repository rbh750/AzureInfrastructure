# Automate the generation and secure storage of cryptographic keys for an application environment. 
# It creates AES (symmetric) and RSA (asymmetric) keys, stores them in Azure Key Vault, and updates an Excel settings file with the generated key values. 
#This ensures that encryption keys are managed securely and are accessible for application configuration and deployment.

param (
    [string]$Environment = "z",
    [string]$KeyVaultName = "z"
)

. "$PSScriptRoot/FindFileByName.ps1" 
$parentDir = Split-Path -Path $PSScriptRoot -Parent 
$rootDir = Split-Path -Path $parentDir -Parent 
$settingsManager = Find-FileByName -FileName "SettingsManager.ps1" -CurrentDirectory $rootDir
. $settingsManager
$settingsFilePath = Find-FileByName -FileName "SettingsIndex.xlsx" -CurrentDirectory $rootDir   
$keyVaultPath = Find-FileByName -FileName "KeyVaultSecrets.ps1" -CurrentDirectory $rootDir    

# 1 AES symetric
# Key size: 256-bit key, which is 32 bytes (or characters)
$keySize = 256

# Generate the key
$aes = [System.Security.Cryptography.Aes]::Create()
$aes.KeySize = $keySize
$key = [byte[]]::new($aes.KeySize / 8)
$iv = [byte[]]::new($aes.BlockSize / 8)
$aes.GenerateKey()
$aes.GenerateIV()
$key = $aes.Key
$iv = $aes.IV

# Convert key and IV to Base64 string for easy display
$keyBase64 = [Convert]::ToBase64String($key)
$ivBase64 = [Convert]::ToBase64String($iv)

# Get the AES key secret name form the excel file
$secretKeyName = GetKeyVaultSecretKeyName `
    -Environment $Environment `
    -SettingPath 'Cryptography:Aes:Base64Key' `
    -ExcelFilePath $settingsFilePath

# Add the AES key to the key vault
. $keyVaultPath `
    -keyVaultName $KeyVaultName `
    -secretName $secretKeyName `
    -secretValue $keyBase64

# Get the AES initialization vector secret name form the excel file
$secretKeyName = GetKeyVaultSecretKeyName `
    -Environment $Environment `
    -SettingPath 'Cryptography:Aes:Base64Iv' `
    -ExcelFilePath $settingsFilePath

# Add the AES initialization vector to the key vault 
. $keyVaultPath `
    -keyVaultName $KeyVaultName `
    -secretName $secretKeyName `
    -secretValue $ivBase64    

# Set the AES key value in the excel file
SetSettingValue `
    -Environment $Environment `
    -SettingPath 'Cryptography:Aes:Base64Key' `
    -SettingValue $keyBase64 `
    -ExcelFilePath $settingsFilePath
    
# Set the AES initialization vector value in the excel file
SetSettingValue `
    -Environment $Environment `
    -SettingPath 'Cryptography:Aes:Base64Iv' `
    -SettingValue $ivBase64 `
    -ExcelFilePath $settingsFilePath            


# 2 RSA asymetric
# Generate RSA key pair
$rsa = [System.Security.Cryptography.RSA]::Create(2048)

# Export keys
$publicKey = [Convert]::ToBase64String($rsa.ExportSubjectPublicKeyInfo())
$privateKey = [Convert]::ToBase64String($rsa.ExportPkcs8PrivateKey())

# Get the RSA private key secret name form the excel file
$secretKeyName = GetKeyVaultSecretKeyName `
    -Environment $Environment `
    -SettingPath 'Cryptography:Rsa:PrivateKey' `
    -ExcelFilePath $settingsFilePath

# Add the RSA private key to the key vault
. $keyVaultPath `
    -keyVaultName $KeyVaultName `
    -secretName $secretKeyName `
    -secretValue  $privateKey

# Get the RSA public key secret name form the excel file
$secretKeyName = GetKeyVaultSecretKeyName `
    -Environment $Environment `
    -SettingPath 'Cryptography:Rsa:PublicKey' `
    -ExcelFilePath $settingsFilePath

# Add the RSA public key to the key vault  
. $keyVaultPath `
    -keyVaultName $KeyVaultName `
    -secretName $secretKeyName `
    -secretValue  $publicKey    

# Set the RSA private key value in the excel file
SetSettingValue `
    -Environment $Environment `
    -SettingPath 'Cryptography:Rsa:PrivateKey' `
    -SettingValue $privateKey `
    -ExcelFilePath $settingsFilePath

# Set the RSA public key value in the excel file
SetSettingValue `
    -Environment $Environment `
    -SettingPath 'Cryptography:Rsa:PublicKey' `
    -SettingValue $publicKey `
    -ExcelFilePath $settingsFilePath            
