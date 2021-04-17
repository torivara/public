param(
    $resourceGroupName,
    $storageAccName,
    $vaultName
)

## Connect to Azure Account
Connect-AzAccount -Identity

## Create a local test file for upload
Write-Output "This is a test" | Out-File -FilePath testfile.txt
$file = Get-Item .\testfile.txt 

## Set storage account blob content
Set-AzCurrentStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccName
Set-AzStorageBlobContent -Container "test" -File ".\testfile.txt" -Blob "testfile.txt"

## Get key vault secret
$secret = Get-AzKeyVaultSecret -VaultName $vaultName -Name 'examplesecret' -AsPlainText
Write-Output $secret
