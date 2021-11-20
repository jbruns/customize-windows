# "standard" Workstation loadout, installed via chocolatey
$desiredPackages = @(
    "7zip.install",
    "adobereader",
    "adoptopenjdk14jre",
    "airexplorer",
    "deluge",
    "discord",
    "filebot",
    "filezilla",
    "firefox",
    "foobar2000",
    "gimp",
    "hexchat",
    "irfanview",
    "powertoys",
    "slack",
    "steam",
    "visualstudiocode",
    "vlc"
)
$localPackages = choco list --localonly --id-only
foreach ($package in $desiredPackages) {
    if ($localPackages -contains $package) {
        choco upgrade $package -y
    }
    else {
        choco install $package -y
    }
}