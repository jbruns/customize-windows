What does this do?
---
These scripts are more or less my starting point for Windows 11 client machines. I want an OS that is hardened in reasonable ways without totally killing convenience or just making life rough, but also one that keeps quiet unless something _actually_ needs your attention.

Luckily, the officially provided Microsoft Security Baseline gets us most of the way there; by essentially starting with a solid security posture, and very carefully dialing back specific things that cater more to a consumer device (like re-enabling Xbox services, for example), we end up with a lean machine that gets out of its own way (and yours).

This repo should work for Windows 11 Pro, Pro for Workstations, and Enterprise. Local, Domain, Azure AD, or Microsoft accounts are all fine as well; though note that in [Azure] Active Directory situations, some policies may be overridden by your friendly IT Department.

Installation
---
- Clone this repository or download it as a .zip, and extract to \win11-deploy-main (or a directory of your choosing).
- head over to https://www.microsoft.com/en-us/download/details.aspx?id=55319 and download the following files:
  - Windows 11 Security Baseline.zip
  - LGPO.zip
- extract the Security Baseline to \win11-deploy-main\Windows11-Security-Baseline-FINAL.
- extract (only) LGPO.exe from LGPO.zip to \win11-deploy-main\Windows11-Security-Baseline-FINAL\Scripts\Tools.
  - you'll know you have the right location when you see **LGPO.txt** in the same directory.

- edit the `Customize-Windows11.ps1` file, and fill in your product key on line 1.
  - if you would like to omit the other steps (like uninstalling OneDrive, or installing Chocolatey), simply comment out or remove those lines.

- (optional) Run `Install-SWL.ps1` to have Chocolatey install any packages that you want. Again feel free to customize the list of packages to your liking.
  - I may switch this to WinGet in the future; but it doesn't seem like there's a straightforward way to automate installing WinGet.

- From here, I really like [StartAllBack](https://www.startallback.com) to help restore some of the start/taskbar/explorer features (and the darn context menus).
