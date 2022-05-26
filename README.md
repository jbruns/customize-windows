# Customize-Windows
A simple set of scripts for repeatable Windows Client settings application, using fully supported means, and no extra binaries.

## What does this do?

These scripts are more or less my starting point for Windows 10 or Windows 11 client machines. I want an OS that is hardened in reasonable ways without totally killing convenience or just making life rough, but also one that keeps quiet unless something _actually_ needs your attention.

Luckily, the officially provided Microsoft Security Baseline gets us most of the way there; by essentially starting with a solid security posture, and very carefully dialing back specific things that cater more to a consumer device (like re-enabling Xbox services, for example), we end up with a lean machine that gets out of its own way (and yours).

This repo should work for any Windows edition (perhaps even Home, but I have not personally tested this). Local, Domain, Azure AD, or Microsoft accounts are all fine as well; though note that in [Azure] Active Directory situations, some policies may be overridden by your friendly IT Department. If, on the other hand, you _are_ the IT Department, consider importing both the Baseline policies and perhaps the settings stored in this repo, to make it both easier to deploy to clients, and to further customize the settings to your liking.

## Wow, how clever, another Windows customizer. Why?

Three goals:
1) no third party binaries (or anything else that doesn't already come with Windows).
2) no Sysprep or modified WIMs, no registry hacks/tweaks.
3) supported configuration changes only (hence heavy reliance on Group Policy).

So in short: simple, and fully supported by a completely unmodified Windows installation source.

## What Exact Settings Are Changed?

- For the Security Baseline, [download](https://www.microsoft.com/en-us/download/details.aspx?id=55319) the relevant files for your Windows version. Inside the .zip file that you receive, you'll want to review the files in the **Documentation** subdirectory. It looks scary - but for most use cases is relatively reasonable.

- For the policy settings in this repository (which will be overlaid on top of the Security Baseline - in the case of duplicate settings, this one "wins"), review the .html file included in the release. This is generated simply by using the GPRESULT utility.

## Suggested "installation" Process

- Head over to the [Releases](https://github.com/jbruns/customize-windows) page, and download the most recent release that supports your Windows version.
- Unzip the resulting file to a directory of your choice, for example, `C:\customize-windows`.
- Make sure your PowerShell execution policy is set to `RemoteSigned`. If it isn't, from an elevated PowerShell window, issue the command `Set-ExecutionPolicy RemoteSigned`.
- Review the parameters for the `Customize-Windows.ps1` script. The defaults are designed to be fairly safe and sane, but you may want to change them to better suit your setup.

>**Note that there is no turning back!** If you've made changes to the Group Policy settings on this machine, you might want to back them up - for any settings _not_ explicitly changed between either the Security Baseline or the policy bundled here, they'll be left as-is. Anything included in any of these policies, though, will be overridden.

- Execute the `Customize-Windows.ps1` script. By default, this will:
  - Gather details about the machine, in order to determine what version the Security Baseline is required, and what parameters to pass to it.
  - Determine whether the script is running on a virtual machine or not, to help decide whether to install things like Hyper-V.
  - If not overridden by command-line parameters, download LGPO.exe and the correct version of the Security Baseline package, from Microsoft. These will be unzipped, and LGPO.exe will be copied to the correct place in the Security Baseline directory structure.
  - Run `Baseline-LocalInstall.ps1` from the Security Baseline.
  - Run LGPO.exe to overlay the policy settings from this repository (overriding any setting that the Security Baseline might have already set).
  - Re-enable Xbox services.
  - Re-enable Xbox Save Game sync task.
  - Disable other services that are not necessary.
  - Install a Product Key (if specified), and trigger Windows activation.
  - Enable one or more Windows optional features.
  - Remove one or more AppX packages (both for the current user, and as "online/provisioned".)
  - Uninstall OneDrive.

If one or more of these operations aren't for you - the included scripts are designed to be human readable and straightforward. You can remove or alter any of the steps without much fear of breakage or interdependencies. For services, features, and apps, the lists of affected items can easily be tailored to your liking (or even overridden on the commandline, if you prefer).

Horribly fatal errors along the way should (hopefully very early) be caught - but there isn't a ton that can go wrong. Re-running will simply set everything again without any harm. Note that you may want to delete, move, or specify on the command line the location of either LGPO.exe (`-LGPOExe`) or the Security Baseline package (`-SecurityBaselinePath`) if you want to use a copy that was downloaded by the script instead.

## Now what?

- From here, I really like [StartIsBack](https://www.startisback.com), to help restore some of the start/taskbar/explorer features (and the old context menus, on Windows 11).
- On Windows 10, I usually trigger an app update from Store, and make sure that ["App Installer" (aka winget)](https://docs.microsoft.com/en-us/windows/package-manager/winget/) is installed. `Install-SWL.ps1` ("Standard Workstation Loadout"?) is a very simple, very lacking of any error handling, way of automating various software package installations for you using winget.
- The entire directory that you initially extracted customize-windows to may be deleted once you are finished with it. No additional state, files or any other resources are created or left behind elsewhere on your machine.

---
<br>

## Configuration Reference
| Parameter | Description | Default
| --------- | ----------- | -------
| `-ProductKey` | Specifies the Windows Product Key for this installation. If not specified, nothing is changed. | (null) |
| `-SecurityBaselinePath` | Specifies the directory where the Security Baseline package is extracted. If not specified, downloads the package from Microsoft. | (null) |
| `-LGPOExe` | Specifies the absolute path to LGPO.exe. If not specified, downloads LGPO from Microsoft. | (null) |
| `-OverlayGPO` | Path to LGPO-created backup of "overlay" settings - that is, changes that will applied AFTER the Security Baseline settings. | Included with release |
| `-ServicesToEnable` | Array of service names that will be restored to 'Manual' start. All Xbox/Gaming services are disabled during Security Baseline application, so by default these services are reset. | "XboxGipSvc", "XblAuthManager", "XblGameSave", "XboxNetApiSvc" |
| `-FeaturesToEnable` | Array of feature names to enable. `Microsoft-Hyper-V` has an additional check to ensure it is being installed on a physical machine. | "TFTP", "TelnetClient", "Microsoft-Windows-Subsystem-Linux", "Microsoft-Hyper-V" |
| `-ServicesToDisable` | Array of service names that will be set to 'Disabled' start. Conservative by default, but be sure to audit the list first for your scenario. | See list below |
| `-AppsToRemove` | Array of AppX package names that will be uninstalled (for the current user and "online/provisioned"). | See list below |
<br>

## Updating the Group Policy Settings

To update the settings alongside a new Windows version, I start with a "clean" VM, installed via an .iso retreived from my.visualstudio.com. 

Instead of applying all of the customizations to this machine, I run LGPO to apply the existing "WorkstationConfigOverlay" policy. For example:

`LGPO /v /g C:\customize-windows\WorkstationConfigOverlay\{7E5797A8-4B91-4F83-ACBE-CFED9FDA1200}`

Then, using `gpedit.msc` and referring to the "New Settings in Windows (version)" spreadsheet which comes with that version's Security Baseline package, I make any relevant changes.

After all that, I export the new policy:

`LGPO /b C:\customize-windows\WorkstationConfigOverlay -n "WorkstationConfigOverlay"`

Note that the specified directory must exist, or LGPO will just keep spitting syntax help at you.

Now, we should have a new `{guid}` directory, which replaces the old one, and contains our new set of settings.

Finally, I run `GPRESULT /H WorkstationConfigOverlay-mmddyy.html` to generate a report of the settings for review.

<br>

---

## Services Disabled by default

| Service | Notes |
| ------- | ----- |
| AJRouter | AllJoyn Router. https://openconnectivity.org/technology/reference-implementation/alljoyn/ |
| ALG | Application Level Gateway |
| PeerDist | BranchCache. https://docs.microsoft.com/en-us/windows-server/networking/branchcache/branchcache |
| dmwappushsvc | https://docs.microsoft.com/en-us/windows/configuration/wcd/wcd-devicemanagement |
| SharedAccess | Internet Connection Sharing |
| iphlpsvc | IP Helper (IPv6 transition) |
| IpxlatCfgSvc | IP Translation Configuration Service (IPv6 transition) |
| MSiSCSI | iSCSI Support |
| SmsRouter | Microsoft Windows SMS Router Service |
| SEMgrSvc | Payments and NFC/SE Manager |
| PhoneSvc | Phone Service |
| RetailDemo | Retail Demo Service |
| wisvc | Windows Insider |
| WMPNetworkSvc | Shares Windows Media Player libraries on the network |
| WwanSvc | Mobile Broadband support |

## AppX packages uninstalled by default

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