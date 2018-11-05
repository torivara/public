<#
.SYNOPSIS
	Installs windows updates on local computer.
.DESCRIPTION
	The script fetches all windows updates available from either Microsoft Update or WSUS (depends on configuration of host), and installs them.
.EXAMPLE
    Install all windows updates and restart computer automatically
	Install-WindowsUpdates.ps1
.INPUTS
	It is not possible to pipe output to this script.
.OUTPUTS
    No outputs from this script. Cannot be piped to cmdlets.
.NOTES
	NAME: Install-WindowsUpdates.ps1
	VERSION: 1.0
	AUTHOR: Tor Ivar Larsen
    CREATED: 2015-12-21
	LASTEDIT: 2015-12-21
#>

[CmdletBinding()]
Param()

function Get-WIAStatusValue($value) 
{ 
   switch -exact ($value) 
   { 
      0   {"NotStarted"} 
      1   {"InProgress"} 
      2   {"Succeeded"} 
      3   {"SucceededWithErrors"} 
      4   {"Failed"} 
      5   {"Aborted"} 
   }  
}

$Criteria = "IsInstalled=0 and IsHidden=0 and Type='Software'"

#Update session
Write-Output "Starting update session."
$UpdateSession = New-Object -ComObject Microsoft.Update.Session

#Search for relevant updates.
Write-Output "Searching for updates."
Write-Output "Criteria: $Criteria"
$Searcher = $UpdateSession.CreateUpdateSearcher()
$SearchResult = $Searcher.Search($Criteria).Updates


#Install updates.
Write-Output "Preparing for installation."
$Installer = New-Object -ComObject Microsoft.Update.Installer

$Counter = 0
$UpdateCount = ($SearchResult | Measure-Object).Count

Write-Output "Available Updates"
If ($UpdateCount -gt 0) {
    $SearchResult | Select-Object Title | Format-Table -AutoSize
    Foreach ($Update in $SearchResult)
    {
        $Counter++
        Write-Output "Processing Update $Counter/$UpdateCount -  $($Update.Title):"

        #Create updates collection
        $UpdatesCollection = New-Object -ComObject Microsoft.Update.UpdateColl
        #Accept EULA if necessary
        if ( $Update.EulaAccepted -eq 0 ) { $Update.AcceptEula() }
        $TMP = $UpdatesCollection.Add($Update)

        #Download update
        $UpdatesDownloader = $UpdateSession.CreateUpdateDownloader() 
        $UpdatesDownloader.Updates = $UpdatesCollection
        $DownloadResult = $UpdatesDownloader.Download()
        $Message = "  - Download {0}" -f (Get-WIAStatusValue $DownloadResult.ResultCode) 
        Write-Output $Message

        #Install update
        $UpdatesInstaller = $UpdateSession.CreateUpdateInstaller()
        $UpdatesInstaller.Updates = $UpdatesCollection 
        $InstallResult = $UpdatesInstaller.Install()
        $Message = "  - Install {0}" -f (Get-WIAStatusValue $InstallResult.ResultCode)
        Write-Output $Message

        If (($InstallResult.ResultCode -eq 2) -or ($InstallResult.ResultCode -eq 3))
        {
            # Specify the registry key 
            $Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results\Install"
            $Name = "LastSuccessTime"
            $date = (Get-Date).AddHours(-1)
            $Value = Get-Date -Date $date -Format "yyyy-MM-dd HH:mm:ss"

            If (Test-Path $Path) { Set-ItemProperty -Path $Path -Name $Name -Value "$Value" }
            Else
            {
                New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results" -Name "Install" -Force | Out-Null
                Set-ItemProperty -Path $Path -Name $Name -Value "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")" | Out-Null
            }
        }

    }

    #Reboot if required by updates.
    Write-Host "Restarting computer in 15 seconds. Press CTRL+C if this is not wanted!" -ForegroundColor Red
    Start-Sleep -Seconds 15
    Restart-Computer -Force -Confirm:$False

}
