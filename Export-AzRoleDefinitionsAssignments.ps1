[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [String]$topLvlMgmtGrp,
    [Parameter(Mandatory = $false)]
    [String]$customRolesOnly = "true",
    [Parameter(Mandatory = $false)]
    [String]$excludeRegexPattern,
    [Parameter(Mandatory = $false)]
    [String]$rolesFolder = "output",
    [Parameter(Mandatory = $false)]
    [Switch]$exportAssignments,
    [Parameter(Mandatory = $false)]
    [String]$subscription
)

$pwshContext = Get-AzContext
while (!$pwshContext) {
    Write-Host "Not logged in with PowerShell. Logging in."
    Connect-AzAccount | Out-Null
    $pwshContext = Get-AzContext
}

$azContext = $(az account show)
while (!$azContext) {
    Write-Host "Not logged in with Azure CLI. Logging in."
    az login | Out-Null
    $azContext = $(az account show)
}

if ($subscription) {
    Write-Host "Changing PowerShell context to subscription $subscription"
    Set-AzContext -Subscription $subscription | Out-Null
    Write-Host "Changing Azure CLI context to subscription $subscription"
    az account set --subscription ($pwshContext.Subscription.Id) | Out-Null
}

if (!(Test-Path $rolesFolder)) {
    New-Item -ItemType Directory -Name $rolesFolder -Force
}

$subscriptions = @()                   # Output array

if ($topLvlMgmtGrp) {
    # Collect data from managementgroups
    $mgmtGroups = Get-AzManagementGroup -GroupId $topLvlMgmtGrp -Expand -Recurse
    $children = $true
    while ($children) {
        $children = $false
        $firstrun = $true
        foreach ($entry in $mgmtGroups) {
            if ($firstrun) { Clear-Variable mgmtGroups ; $firstrun = $false }
            if ($entry.Children.length -gt 0) {
                # Add management group to data that is being looped throught
                $children = $true
                $mgmtGroups += $entry.Children
            }
            else {
                if ($entry.Name.Length -eq 36) {
                    # Add subscription to output object
                    $subscriptions += New-Object -TypeName psobject -Property ([ordered]@{'DisplayName' = $entry.DisplayName; 'SubscriptionID' = $entry.Name })
                }
            }
        }
    }
}
else {
    $subscriptions += New-Object -TypeName psobject -Property ([ordered]@{'DisplayName' = (Get-AzContext).Subscription.Name; 'SubscriptionID' = (Get-AzContext).Subscription.Id })
}

$exported = @()
$assignmentsList = @()

foreach ($sub in $subscriptions) {
    Write-Host "Processing $($sub.DisplayName)."
    $roles = $(az role definition list --custom-role-only $customRolesOnly --scope "/subscriptions/$($sub.SubscriptionID)" | ConvertFrom-Json)
    foreach ($role in $roles) {
        if ($role.roleName -like "$($excludeRegexPattern)") {
            Write-Host "$($role.roleName) excluded by regexpattern."
        }
        elseif ($role.name -notin $exported -and $role.roleName -notlike "$($excludeRegexPattern)") {
            $fileName = $role.roleName.toLower() -replace "custom - ", "" -replace " ", "_" -replace "-", "_" -replace "/", "_"
            Write-Host "Exporting $($role.roleName) to file..."
            $role | ConvertTo-Json -Depth 15 | out-file "$rolesFolder/role_definition_$($fileName).json" -encoding "utf8"
            $exported += $role.name
        }
        else {
            Write-Host "$($role.roleName) already exported."
        }
        if ($exportAssignments) {
            $assignments = Get-AzRoleAssignment -Scope "/subscriptions/$($sub.SubscriptionID)" | Where-Object { $_.RoleDefinitionId -eq $role.name }
            foreach ($ass in $assignments) {
                $assignmentsList += [PSCustomObject]@{
                    RoleDefinitionId     = $ass.RoleDefinitionId
                    RoleDefinitionName   = $ass.RoleDefinitionName
                    AssignedSubscription = $sub.SubscriptionID
                    AssignmentId         = $ass.RoleAssignmentId
                    ObjectId             = $ass.ObjectId
                    SignInName           = $ass.SignInName
                    DisplayName          = $ass.DisplayName
                    Description          = $ass.Description
                    Scope                = $ass.Scope
                }
            }
        }
    }
}

Write-Host "Exported roles"
$exported | format-table -autosize

if ($exportAssignments) {
    Write-Host "Exporting assignments"
    $assignmentsList | ConvertTo-Json | Out-File assignments.json -Force
}
