$key = "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE"
$SB = (Resolve-Path ".\Windows11-Security-Baseline-FINAL").Path
$LGPOExe = Join-Path $SB "\Scripts\Tools\LGPO.exe"
$WorkstationConfigGPO = (Resolve-Path ".\WorkstationConfigOverlay\{E49AD3B3-A9C7-4231-8DE4-92B3AD80B863}").Path

Write-Host "Applying Windows Security Baseline."
Push-Location (Join-Path $SB "\Scripts")
.\Baseline-LocalInstall.ps1 -Win11NonDomainJoined

Pop-Location
Write-Host "Applying Workstation customizations."
Start-Process -FilePath $LGPOExe -ArgumentList "/v /g $WorkstationConfigGPO" -NoNewWindow

Write-Host "Restoring Xbox services startup type."
$XboxServices = @(
"XboxGipSvc",
"XblAuthManager",
"XblGameSave",
"XboxNetApiSvc"
)

foreach ($XboxService in $XboxServices) {
    Set-Service -Name $XboxService -StartupType Manual
}

Write-Host "Restoring XblGameSave scheduled task."
SCHTASKS.EXE /Change /TN \Microsoft\XblGameSave\XblGameSaveTask /ENABLE

Write-Host "Applying product key and activating Windows."
$computer = gc env:computername
$service = get-wmiObject -query "select * from SoftwareLicensingService" -computername $computer
$service.InstallProductKey($key)
$service.RefreshLicenseStatus()

Write-Host "Enabling additional Windows features."
.\Install-WindowsFeatures.ps1

Write-Host "Removing AppX packages."
.\RemoveApps.ps1

Write-Host "Uninstalling OneDrive."
C:\Windows\SysWOW64\OneDriveSetup.exe /Uninstall

Write-Host "Installing Chocolatey."
.\Install-Chocolatey.ps1

