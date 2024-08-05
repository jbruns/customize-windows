param (
    # Windows product key. If not specified, product key will not be changed.
    $ProductKey,

    # Path to the Security Baseline files. 
    # If not specified, this script will attempt to download the Security Baseline files for the current Windows version from Microsoft.
    $SecurityBaselinePath, # = (Resolve-Path ".\Windows-10-v21H2-Security-Baseline").Path,

    # Absolute path to LGPO.exe.
    # If not specified, this script will attempt to download LGPO.zip from Microsoft.
    $LGPOExe, # = Join-Path $SecurityBaselinePath "\Scripts\Tools\LGPO.exe",

    # Path to LGPO-created backup of "overlay" settings - that is, changes that will applied AFTER the Security Baseline settings.
    $OverlayGPO = (Resolve-Path ".\WorkstationConfigOverlay\{D0E0AD46-0107-46F7-B4DC-8F4CCBAA3DA1}").Path,
    
    # Array of service names belonging to Xbox/Gaming, which will be re-enabled following Security Baseline application
    $ServicesToEnable = @(
        "XboxGipSvc",
        "XblAuthManager",
        "XblGameSave",
        "XboxNetApiSvc"
    ),

    # Array of Windows Optional Features to enable. 
    # There is an additional check for Hyper-V to ensure the machine is not a VM, so if you want nested virt, no-op that check below.
    $FeaturesToEnable = @(
        "Microsoft-Windows-Subsystem-Linux",
        "Microsoft-Hyper-V-Tools-All",
        "Microsoft-Hyper-V-Services",
        "VirtualMachinePlatform"
    ),

    # Array of service names that will be set to Disabled state. Check this list and ensure that none are required in your situation.
    # Nothing is uninstalled - so merely restoring these to the default StartupType state will be enough to restore their functionality.
    $ServicesToDisable = @(
        # https://openconnectivity.org/technology/reference-implementation/alljoyn/
        # AllJoyn (no longer relevant?)
        "AJRouter",
        # Application Level Gateway
        "ALG",
        # Internet Connection Sharing
        "SharedAccess",
        # Microsoft Windows SMS Router Service
        "SmsRouter",
        # Payments and NFC/SE Manager
        "SEMgrSvc",
        # Phone Service
        "PhoneSvc",
        # Retail Demo Service
        "RetailDemo",
        # Enables Windows Insider features
        "wisvc",
        # Share WMP Libraries to other machines
        "WMPNetworkSvc",
        # Mobile broadband support
        "WwanSvc"
    ),

    # Array of AppX package names that will be uninstalled (for the current user and "online/provisioned").
    $AppsToRemove = @(
        # Windows 10 specific
        "Microsoft.Office.OneNote",
        "Microsoft.Messaging",
        "Microsoft.SkypeApp",
        # Windows 11 + Windows 10 common
        "Clipchamp.Clipchamp",
        "Microsoft.BingNews",
        "Microsoft.BingWeather",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.MicrosoftOfficeHub",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.MicrosoftStickyNotes",
        "Microsoft.OutlookForWindows",
        "Microsoft.Paint",
        "Microsoft.People",
        "Microsoft.PowerAutomateDesktop",
        "Microsoft.Windows.DevHome",
        "Microsoft.Windows.Photos",
        "Microsoft.WindowsAlarms",
        "Microsoft.windowscommunicationsapps",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.WindowsMaps",
        "Microsoft.WindowsSoundRecorder",
        "Microsoft.YourPhone",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo",
        "MicrosoftCorporationII.QuickAssist"
    )
)

# Locations from where Security Baseline and LGPO files will be retreived, if necessary.
$DownloadLocations = @{
    "LGPO" = "https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/LGPO.zip"
    "Win11" = @{
        "22H2" = "https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/Windows%2011%20version%2022H2%20Security%20Baseline.zip"
        "23H2" = "https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/Windows%2011%20v23H2%20Security%20Baseline.zip"
    }
    "Win10" = @{
        "22H2" = "https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/Windows%2010%20version%2022H2%20Security%20Baseline.zip"
    }
}

If (-Not(Test-Path $OverlayGPO)) {
    Write-Error "Cannot find Overlay GPO at $OverlayGPO. This path can be overridden using the -OverlayGPO parameter." -ErrorAction Stop
}

# Determine Windows version
$ComputerInfo = Get-ComputerInfo
$WindowsDisplayVersion = $ComputerInfo.OsDisplayVersion

If ($ComputerInfo.OsName -like "*Windows Server*") {
    Write-Error "This script does not support Windows Server, but the Security Baseline package by itself does." -ErrorAction Stop
}

Switch ($ComputerInfo.CsModel) {                
    # Hyper-V
    "Virtual Machine" {
        $MachineType="VM"
    }

    # VMWare
    "VMware Virtual Platform" {
        $MachineType="VM"
    }

    # Oracle VM
    "VirtualBox" {
        $MachineType="VM"
    }

    # Xen
    "HVM domU" {
        $MachineType="VM"
    }

    # If none of the other cases, then physical
    default {
        $MachineType="Physical"
    }
}

Switch ($ComputerInfo.OsName.SubString(0,20)) {
    "Microsoft Windows 10" {
        $WindowsVersion = "Win10"
    }
    "Microsoft Windows 11" {
        $WindowsVersion = "Win11"
    }
}

Switch ($ComputerInfo.CsDomainRole) {
    "StandaloneWorkstation" {
        $DomainRole += "NonDomainJoined"
    }
    "MemberWorkstation" {
        $DomainRole += "DomainJoined"
    }
}

If ((-Not($WindowsVersion) -or (-Not($DomainRole)))) {
    Write-Error "Couldn't determine Windows version (10? 11?) or domain join state." -ErrorAction Stop
}
$SecurityBaselineArgs = @{}
$SecurityBaselineArgs.Add($WindowsVersion + $DomainRole,"")

# Check for LGPO.exe and if not explicitly specified, download it.
If (-Not($LGPOExe)) {
    # Verify that there isn't already an LGPO.exe
    $LGPOFilenames = Get-ChildItem -Path $PSScriptRoot -File -Filter "LGPO.exe" -Recurse | Select-Object FullName
    If ($LGPOFilenames.FullName.Count -gt 0) {
        Write-Host $LGPOFilenames
        Write-Error "Found existing LGPO.exe in the path $PSScriptRoot. Either specify the location of LGPO.exe to be used, or remove the existing file(s)." -ErrorAction Stop
    }
    $LGPOzip = Join-Path $PSScriptRoot "\LGPO.zip"
    Invoke-WebRequest -Uri $DownloadLocations.LGPO -OutFile $LGPOzip
    If (-Not(Test-Path $LGPOzip)) {
        Write-Error "Failed to download LGPO.zip from $($DownloadLocations.LGPO)." -ErrorAction Stop
    }
    Expand-Archive $LGPOzip -DestinationPath $PSScriptRoot # -PassThru should be an option in later PS versions so we won't have to do the following..
    $LGPOExe = (Get-ChildItem -Path $PSScriptRoot -File -Filter "LGPO.exe" -Recurse | Select-Object FullName)[0].FullName
}

If (-Not(Test-Path $LGPOExe)) {
        Write-Error "Cannot find LGPO.exe at $LGPOExe." -ErrorAction Stop
}

# Check for existing Security Baseline path and if not explicitly specified, download the correct one for this Windows version.
If (-Not($SecurityBaselinePath)) {
    If (-Not($DownloadLocations.$WindowsVersion.$WindowsDisplayVersion)) {
        Write-Error "This Windows version ($WindowsVersion $WindowsDisplayVersion) doesn't have an assigned download location for the Security Baseline. You can specify a local copy using -SecurityBaselinePath." -ErrorAction Stop
    }
    $SecurityBaselineZip = Join-Path $PSScriptRoot "\SecurityBaseline.$WindowsVersion.$WindowsDisplayVersion.zip"
    Invoke-WebRequest -Uri $DownloadLocations.$WindowsVersion.$WindowsDisplayVersion -OutFile $SecurityBaselineZip
    If (-Not(Test-Path $SecurityBaselineZip)) {
        Write-Error "Failed to download Security Baseline from $($DownloadLocations.$WindowsVersion.$WindowsDisplayVersion)." -ErrorAction Stop
    }
    Expand-Archive $SecurityBaselineZip -DestinationPath $PSScriptRoot # -PassThru should be an option in later PS versions so we won't have to do the following..
    $SecurityBaselinePath = (Get-ChildItem -Path $PSScriptRoot -Directory -Filter "*Baseline*" -Recurse | Select-Object FullName)[0].FullName
}

If (-Not(Test-Path (Join-Path $SecurityBaselinePath "\Scripts\Baseline-LocalInstall.ps1"))) {
        Write-Error "Security Baseline path at $SecurityBaselinePath does not appear to be correct - looking for \Scripts\Baseline-LocalInstall.ps1." -ErrorAction Stop
}

# Satisfy LGPO.exe dependency if needed for Security Baseline
If (-Not(Test-Path (Join-Path $SecurityBaselinePath "\Scripts\Tools\LGPO.exe"))) {
        Copy-Item -Path $LGPOExe -Destination (Join-Path $SecurityBaselinePath "\Scripts\Tools\LGPO.exe")
}

Write-Host "Applying Windows Security Baseline."
Push-Location (Join-Path $SecurityBaselinePath "\Scripts")
.\Baseline-LocalInstall.ps1 @SecurityBaselineArgs
Pop-Location

Write-Host "Applying Workstation customizations."
Start-Process -FilePath $LGPOExe -ArgumentList "/v /g $OverlayGPO" -NoNewWindow

Write-Host "Enabling/restoring services startup state."
foreach ($ServiceName in $ServicesToEnable) {
    Set-Service -Name $ServiceName -StartupType Manual
}

Write-Host "Restoring XblGameSave scheduled task."
SCHTASKS.EXE /Change /TN \Microsoft\XblGameSave\XblGameSaveTask /ENABLE

Write-Host "Disabling uneccessary services."
foreach ($ServiceName in $ServicesToDisable) {
    Set-Service -Name $ServiceName -StartupType Disabled
}

If ($ProductKey) {
    Write-Host "Applying product key and activating Windows."
    $ComputerName = Get-Content Env:COMPUTERNAME
    $SoftwareLicensingService = Get-WmiObject -Query "Select * From SoftwareLicensingService" -ComputerName $ComputerName
    $SoftwareLicensingService.InstallProductKey($ProductKey)
    $SoftwareLicensingService.RefreshLicenseStatus()
}

Write-Host "Enabling additional Windows features."
foreach ($FeatureName in $FeaturesToEnable) {
    Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -NoRestart
    # If it's Hyper-V, then also check to see if this is a physical machine.
    If (($FeatureName -eq "Microsoft-Hyper-V") -and ($MachineType -eq "Physical")) {
        Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -All -NoRestart
    }
}

Write-Host "Removing AppX packages."
ForEach ($App in $AppsToRemove) {
	$PackageFullName = (Get-AppxPackage $App).PackageFullName
    $ProvPackageFullName = (Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq $App}).PackageName
    If ($PackageFullName) {
		Write-Host "Removing Package: $App"
		Remove-AppxPackage -package $PackageFullName
	}
	Else {
		Write-Host "Unable to find package: $App"
	}
	If ($ProvPackageFullName) {
		Write-Host "Removing Provisioned Package: $ProvPackageFullName"
		Remove-AppxProvisionedPackage -online -packagename $ProvPackageFullName
	}
	Else {
		Write-Host "Unable to find provisioned package: $App"
	}
}

Write-Host "Uninstalling OneDrive."
C:\Windows\SysWOW64\OneDriveSetup.exe /Uninstall
