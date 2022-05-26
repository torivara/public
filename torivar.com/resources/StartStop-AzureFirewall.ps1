[CmdletBinding()]
param (
    [ValidateSet("deallocate","allocate")]
    [Parameter(Mandatory=$false)]
    [string]$mode="deallocate",
    [Parameter(Mandatory=$true)]
    [string]$subscription,
    [Parameter(Mandatory=$true)]
    [string]$fwName,
    [Parameter(Mandatory=$true)]
    [string]$rgName,
    [Parameter(Mandatory=$false)]
    [bool]$dryrun=$true,
    [Parameter(Mandatory=$false)]
    [string]$vnetName,
    [Parameter(Mandatory=$false)]
    [string]$pipName

)
# Install required modules
if (-not (Get-Module -Name "Az.Accounts" -ListAvailable)) {
  Install-Module -Name Az.Accounts -Scope CurrentUser -Repository PSGallery
  
}
if (-not (Get-Module -Name "Az.Accounts")) {
  Import-Module -Name Az.Accounts
}

if (-not (Get-Module -Name "Az.Network" -ListAvailable)) {
  Install-Module -Name Az.Network -Scope CurrentUser -Repository PSGallery
}

if (-not (Get-Module -Name "Az.Network")) {
  Import-Module -Name Az.Network
}

<#
  Connect to Azure Subscription
  DO NOT TEST THIS IN PRODUCTION AS IT WILL STOP YOUR FIREWALL!
#>
$context = Get-AzContext
if (-not $context.Tenant) {
  Connect-AzAccount
  Set-AzContext -Subscription $subscription
} else {
  Write-Host "Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"
  Write-Host "Tenant: $($context.Tenant.Id)"
}

# Get the firewall object into a variable
$azfw = Get-AzFirewall -Name $fwName -ResourceGroupName $rgName

# Process firewall allocate or deallocate
if ($mode -eq "deallocate" -and $azFw) {
  if ($dryrun){
    Write-Host "Would stop and deallocate firewall"
  } else {
    $azfw.Deallocate()
    Set-AzFirewall -AzureFirewall $azfw
  }
} elseif ($mode -eq "allocate" -and $azFw) {
  if ($dryrun){
    Write-Host "Would start and allocate firewall"
  } else {
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName
    $pip = Get-AzPublicIpAddress -ResourceGroupName $rgName -Name $pipName
    $azFw.Allocate($vnet, $pip)
    Set-AzFirewall -AzureFirewall $azfw
  }
}

<#
  Send the local variable with deallocated firewall setting to Azure
  This will stop your firewall, and stop your running cost for it
#>
