<# 
.DESCRIPTION 
 This script will delete an entire tree of Management Groups if they do not contain any subscriptions.
 
.SYNOPSIS
 Delete Azure Management Groups recursively.

.DESCRIPTION
  You need to log in with an Azure account. Then this script can be run and pointed at a Management Group.
  It will then recursively traverse the tree and delete the Management Groups.
  The Root Management Group can't be deleted.

  Before any deletions are performed, a Az Graph search query will check for any subscriptions in the tree.
  If there are subscriptions present, nothing will be deleted, as this script does not delete or move subscriptions.

  If you try to delete the default Management Group, you will be presented with a choice of which new Management
  Group to set as default.

.PARAMETER mgName
  This is a required parameter, and is the name or id of the management group you want to recursively delete.

.PARAMETER dryrun
  This is not a required parameter, but will run in a dryrun mode to write which changes would be performed.
  This is a nice first run, but will not catch default management group.

.EXAMPLE
  Run to check which Management Groups would be deleted (dryrun is true when not explicitly set to false, but can be set anyway)
  .\remove-managementgroup.ps1 -mgName managementGroupName -dryrun $true

.EXAMPLE
  Run to actually delete the Management Groups in tree
  .\remove-managementgroup.ps1 -mgName managementGroupName -dryrun $false

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$mgName,
    [Parameter(Mandatory=$false)]
    [boolean]$dryrun=$true
)

function Remove-ManagementGroupRecursive() {
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$name,
    [Parameter(Mandatory=$false)]
    [boolean]$dryrun=$true
)
  #Enters the parent Level
  Write-Host "Processing Management Group $name" -ForegroundColor Green
  #Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
  $parent = Get-AzManagementGroup -GroupId $name -Expand -Recurse -WarningAction SilentlyContinue

  #Checks if there is any parent level.
  if($null -ne $parent.Children)
  {
    Write-Host "Found the following Children in Management Group $($parent.DisplayName)`:" -ForegroundColor White
    $parent.Children | Select-Object Name | ForEach-Object {Write-Host "  - $($_.name)" -ForegroundColor Yellow}
    foreach($children in $parent.Children)
    {
      #tries to recurs to each child item
      if ($dryrun) {
        Remove-ManagementGroupRecursive -name $($children.Name) -dryrun $true
      } else {
        Remove-ManagementGroupRecursive -name $($children.Name) -dryrun $false
      }
    }
  }

  
  #Comment the below line if you just want to understand the flow
  if ($dryrun) {
    Write-Host "Would remove the scope $name" -ForegroundColor Cyan
  } else {
    Write-Host "Removing the scope $name" -ForegroundColor Cyan
    try {
      Remove-AzManagementGroup -InputObject $parent -ErrorVariable catchError -ErrorAction Stop
    }
    catch {
      if ($catchError.message -like "*Cannot delete the default Management Group*") {
        Write-Host "You are trying to delete the default management group where new subscriptions are automatically placed." -ForegroundColor Yellow
        Write-Host "To cancel the operation, leave as is. To set back to default (Root Management Group), enter 'default'." -ForegroundColor Yellow
        $userInput = Read-Host -Prompt "Please provide a new default mg"
        $uri = "https://management.azure.com$((Get-AzManagementGroup)[0].Id)/settings/default?api-version=2020-05-01"
        while (-not $done) {
          if ($userInput -eq "") {
            Write-Host "Cancelling..."
            Exit
          } elseif ($userInput -eq "default") {
            $mg = (Get-AzManagementGroup)[0]
            Write-Host "Default mg for new subscriptions will be set to $($mg.DisplayName)" -ForegroundColor Yellow
            $done = $true
          } else {
            $mg = (Get-AzManagementGroup -GroupId "$userInput")
            Write-Host "Default mg for new subscriptions will be set to $($mg.DisplayName)" -ForegroundColor Yellow
            $done = $true
          }
          $payloadTable = @{
            properties = @{
              defaultManagementGroup = $mg.id
            }
          }
          $payload = $payloadTable | ConvertTo-Json
          $response = Invoke-AzRestMethod -Method PUT -Payload $payload -Uri $uri
          Write-Host "Sleeping for 5 seconds because sync"
          Start-Sleep -Seconds 5
          if ($response.StatusCode -eq 200) {
            Remove-AzManagementGroup -InputObject $parent -ErrorVariable catchError -ErrorAction Stop
          } else {
            Write-Host "Something went wrong."
            $response.Content | ConvertFrom-Json
          }
        }
      } else {
        Write-Host "Something went wrong."
        $catchError
      }
      
    }
    
  }
  
}

function Get-MgSubscriptions {
  [CmdletBinding()]
  param (
      [Parameter(Mandatory=$true)]
      [string]$name
  )
  $subscriptions = Search-AzGraph -Query "ResourceContainers | where type =~ 'microsoft.resources/subscriptions'" -ManagementGroup $name
  if ($subscriptions.Data.Count -gt 0) {
    return $subscriptions.Data
  } else {
    return $null
  }
}

$context = Get-AzContext

if (-not $context.Tenant.id) {
  Write-Host "Not authenticated to Azure. Redirecting you to login in a browser."
  Connect-AzAccount
}

$subs = Get-MgSubscriptions -name $mgName

if ($subs) {
  Write-Host "There are subscriptions in mg $mgName. Please move subscriptions before attempting to delete it."
  $subs | Select-Object name,@{ Name = 'ManagementGroupLocation';  Expression = {$_.properties.managementGroupAncestorsChain.displayName -join "->"}},subscriptionId | Format-Table -AutoSize
} else {
  if ($dryrun) {
    Remove-ManagementGroupRecursive -name $mgName -dryrun $true
  } else {
    Write-Host "Please be aware that this will delete group '$mgName' and all sub-level management groups." -ForegroundColor Yellow
    Write-Host "Non-empty groups or default groups will cause error." -ForegroundColor Yellow
    Write-Host "Press Ctrl + C during the next 10 seconds if you changed your mind." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Remove-ManagementGroupRecursive -name $mgName -dryrun $false
  }
}
