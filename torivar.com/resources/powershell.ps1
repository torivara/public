$servicePrincipalName = "YourServicePrincipalNameHere"
$resourceGroupName = "YourResourceGroupNameHere"
$subscriptionName = "YourSubscriptionNameHere"

Write-Host "Changing context to $subscriptionName subscription"
Set-AzContext -Subscription "$subscriptionName"

$rg = Get-AzResourceGroup -Name $resourceGroupName

Write-Host "Creating Service Principal $servicePrincipalName..." -NoNewline
$sp = New-AzADServicePrincipal -DisplayName $servicePrincipalName `
-Scope $rg.ResourceId -Role "Contributor"
Write-Host "done"

$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sp.Secret)
$UnsecureSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

Write-Host "Service Principal Created"
Write-Host "This is the only time the password will be available in clear text. Document in a safe place before clearing window or terminal log!"
Write-Host "Application Id: $($sp.ApplicationId)"
Write-Host "Application Password: $UnsecureSecret"
Write-Host "Tenant Id: $((Get-AzContext).Tenant.Id)"
Write-Host "Subscription Id: $((Get-AzContext).Subscription.Id)"