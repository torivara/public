Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false | Out-Null
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -Confirm:$false
Install-Module PSWindowsUpdate -Force -Confirm:$false
Add-WUServiceManager -ServiceID 7971f918-a847-4430-9279-4a52d1efe18d -Confirm:$false | Out-Null
Get-WUInstall –MicrosoftUpdate –AcceptAll –AutoReboot -Install
