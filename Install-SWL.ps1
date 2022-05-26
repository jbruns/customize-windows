# "standard" Workstation loadout, installed via winget
$desiredPackages = @(
	"voidtools.everything",
	"discord.discord",
	"mozilla.firefox",
	"slacktechnologies.slack",
	"notepad++.notepad++",
	"microsoft.visualstudiocode",
	"7zip.7zip",
	"airexplorer.airexplorer",
	"startisback.startisback",
	"IrfanSkiljan.IrfanView",
	"Valve.Steam",
	"Microsoft.PowerToys",
	"GIMP.GIMP",
	"HexChat.HexChat",
	"TimKosse.FileZilla.Client",
	"PeterPawlowski.foobar2000",
	"VideoLAN.VLC",
	"Nextcloud.NextcloudDesktop",
	"Spotify.Spotify"
)
$localPackages = winget list
foreach ($package in $desiredPackages) {
    if ($localPackages -match [regex]::Escape($package)) {
        winget upgrade $package --accept-package-agreements --accept-source-agreements
    }
    else {
        winget install $package --accept-package-agreements --accept-source-agreements
    }
}