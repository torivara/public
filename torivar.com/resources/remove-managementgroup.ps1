[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$mgName,
    [Parameter(Mandatory=$false)]
    [boolean]$dryrun=$true
)

function Remove-ManagementGroupForce() {
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
        Remove-ManagementGroupForce -name $($children.Name) -dryrun $true
      } else {
        Remove-ManagementGroupForce -name $($children.Name) -dryrun $false
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

$subs = Get-MgSubscriptions -name $mgName

if ($subs) {
  Write-Host "There are subscriptions in mg $mgName. Please move subscriptions before attempting to delete it."
  $subs | Select-Object name,@{ Name = 'ManagementGroupLocation';  Expression = {$_.properties.managementGroupAncestorsChain.displayName -join "->"}},subscriptionId | Format-Table -AutoSize
} else {
  if ($dryrun) {
    Remove-ManagementGroupForce -name $mgName -dryrun $true
  } else {
    Write-Host "Please be aware that this will delete group '$mgName' and all sub-level management groups." -ForegroundColor Yellow
    Write-Host "Non-empty groups or default groups will cause error." -ForegroundColor Yellow
    Write-Host "Press Ctrl + C during the next 10 seconds if you changed your mind." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Remove-ManagementGroupForce -name $mgName -dryrun $false
  }
}
