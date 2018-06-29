# Script installs NuGet and suppresses confirm dialogs. NuGet needed for Install-Module
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false | Out-Null

# Make sure repository name PSGallery is trusted
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -Confirm:$false

# Install Windows Update module from PSGallery
Install-Module PSWindowsUpdate -Force -Confirm:$false

# Add Microsoft Update
Add-WUServiceManager -ServiceID 7971f918-a847-4430-9279-4a52d1efe18d -Confirm:$false | Out-Null

# Fetch and install updates, automatic reboot
Get-WUInstall –MicrosoftUpdate –AcceptAll –AutoReboot -Install
