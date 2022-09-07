# Input bindings are passed in via param block.
param($Timer)

Connect-AzAccount -Identity

$AllRGs = (Get-AzResourceGroup).ResourceGroupName
$UsedRGs = (Get-AzResource | Group-Object ResourceGroupName).Name
$EmptyGroups = $AllRGs | Where-Object {$_ -notin $UsedRGs}

# Write out empty resource groups
Write-Output "These resource groups are empty:"

Foreach ($group in $EmptyGroups) {
    Write-Output "- $group"
}
