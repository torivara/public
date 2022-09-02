

$spns = Get-AzADServicePrincipal | where {$_.DisplayName -like "mdir-*"}


foreach ($spn in $spns) {
  Write-Output $spn.AppDisplayName
  Get-AzADServicePrincipalCredential -ObjectId $spn.id
}