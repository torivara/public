<# 
.DESCRIPTION 
 This script is intended to be run as a part of Update Management Pre/Post scripts.
It requires a RunAs account and the usage of the Turn On VMs script as a pre-deployment script.
This script will ensure all Azure VMs in the Update Deployment are turned off after they recieve updates.
 
This script reads the name of machines that were started by Update Management via the Turn On VMs script
#> 

#requires -Modules ThreadJob
<#
.SYNOPSIS
 Start VMs as part of an Update Management deployment

.DESCRIPTION
  This script is intended to be run as a part of Update Management Pre/Post scripts. 
  It requires a RunAs account.
  This script will ensure all Azure VMs in the Update Deployment are running so they recieve updates.
  This script will store the names of machines that were started in an Automation variable so only those machines
  are turned back off when the deployment is finished (UpdateManagement-TurnOffVMs.ps1)

.PARAMETER SoftwareUpdateConfigurationRunContext
  This is a system variable which is automatically passed in by Update Management during a deployment.

#>

param(
    [string]$SoftwareUpdateConfigurationRunContext
)


#region BoilerplateAuthentication
#This requires a RunAs account
$ServicePrincipalConnection = Get-AutomationConnection -Name 'AzureRunAsConnection'

Connect-AzAccount `
    -ServicePrincipal `
    -TenantId $ServicePrincipalConnection.TenantId `
    -ApplicationId $ServicePrincipalConnection.ApplicationId `
    -CertificateThumbprint $ServicePrincipalConnection.CertificateThumbprint

$AzureContext = Select-AzSubscription -SubscriptionId $ServicePrincipalConnection.SubscriptionID
#endregion BoilerplateAuthentication


#If you wish to use the run context, it must be converted from JSON
$context = ConvertFrom-Json  $SoftwareUpdateConfigurationRunContext
$vmIds = $context.SoftwareUpdateConfigurationSettings.AzureVirtualMachines
$runId = "PrescriptContext" + $context.SoftwareUpdateConfigurationRunId

if (!$vmIds) 
{
    #Workaround: Had to change JSON formatting
    $Settings = ConvertFrom-Json $context.SoftwareUpdateConfigurationSettings
    #Write-Output "List of settings: $Settings"
    $VmIds = $Settings.AzureVirtualMachines
    #Write-Output "Azure VMs: $VmIds"
    if (!$vmIds) 
    {
        Write-Output "No Azure VMs found"
        return
    }
}

#https://github.com/azureautomation/runbooks/blob/master/Utility/ARM/Find-WhoAmI
# In order to prevent asking for an Automation Account name and the resource group of that AA,
# search through all the automation accounts in the subscription 
# to find the one with a job which matches our job ID
$AutomationResource = Get-AzResource -ResourceType Microsoft.Automation/AutomationAccounts

foreach ($Automation in $AutomationResource)
{
    $Job = Get-AzAutomationJob -ResourceGroupName $Automation.ResourceGroupName -AutomationAccountName $Automation.Name -Id $PSPrivateMetadata.JobId.Guid -ErrorAction SilentlyContinue
    if (!([string]::IsNullOrEmpty($Job)))
    {
        $ResourceGroup = $Job.ResourceGroupName
        $AutomationAccount = $Job.AutomationAccountName
        break;
    }
}

#This is used to store the state of VMs
New-AzAutomationVariable -ResourceGroupName $ResourceGroup -AutomationAccountName $AutomationAccount -Name $runId -Value "" -Encrypted $false

$updatedMachines = @()
$startableStates = "stopped" , "stopping", "deallocated", "deallocating"
$jobIDs= New-Object System.Collections.Generic.List[System.Object]

#Parse the list of VMs and start those which are stopped
#Azure VMs are expressed by:
# subscription/$subscriptionID/resourcegroups/$resourceGroup/providers/microsoft.compute/virtualmachines/$name
$vmIds | ForEach-Object {
    $vmId =  $_
    
    $split = $vmId -split "/";
    $subscriptionId = $split[2]; 
    $rg = $split[4];
    $name = $split[8];
    Write-Output ("Subscription Id: " + $subscriptionId)
    $mute = Select-AzSubscription -Subscription $subscriptionId

    $vm = Get-AzVM -ResourceGroupName $rg -Name $name -Status -DefaultProfile $mute 

    #Query the state of the VM to see if it's already running or if it's already started
    $state = ($vm.Statuses[1].DisplayStatus -split " ")[1]
    if($state -in $startableStates) {
        Write-Output "Starting '$($name)' ..."
        #Store the VM we started so we remember to shut it down later
        $updatedMachines += $vmId
        $newJob = Start-ThreadJob -ScriptBlock { param($resource, $vmname, $sub) $context = Select-AzSubscription -Subscription $sub; Start-AzVM -ResourceGroupName $resource -Name $vmname -DefaultProfile $context} -ArgumentList $rg,$name,$subscriptionId
        $jobIDs.Add($newJob.Id)
    }else {
        Write-Output ($name + ": no action taken. State: " + $state) 
    }
}

$updatedMachinesCommaSeperated = $updatedMachines -join ","
#Wait until all machines have finished starting before proceeding to the Update Deployment
$jobsList = $jobIDs.ToArray()
if ($jobsList)
{
    Write-Output "Waiting for machines to finish starting..."
    Wait-Job -Id $jobsList
}

foreach($id in $jobsList)
{
    $job = Get-Job -Id $id
    if ($job.Error)
    {
        Write-Output $job.Error
    }

}

Write-output $updatedMachinesCommaSeperated
#Store output in the automation variable
Set-AutomationVariable -Name $runId -Value $updatedMachinesCommaSeperated
