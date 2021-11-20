$AppList = @(
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.ZuneMusic"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.BingWeather"
    "Microsoft.ZuneVideo"
    "Microsoft.Office.OneNote"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.Messaging"
    "Microsoft.Getstarted"
    "Microsoft.GetHelp"
    "Microsoft.windowscommunicationsapps",
    "Microsoft.SkypeApp"
)
ForEach ($App in $AppList) {
	$PackageFullName = (Get-AppxPackage $App).PackageFullName
    $ProvPackageFullName = (Get-AppxProvisionedPackage -online | where {$_.Displayname -eq $App}).PackageName
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