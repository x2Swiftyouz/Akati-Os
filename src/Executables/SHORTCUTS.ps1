.\AtlasModules\initPowerShell.ps1
$windir = [Environment]::GetFolderPath('Windows')

Write-Title "Creating Desktop & Start Menu shortcuts..."

# Akati OS: no "Atlas" shortcut on the desktop or in the Start menu. Every setting of the Atlas folder
# (AtlasDesktop) is in Akati OS Center > System settings.

Write-Title "Creating services restore shortcut..."
$desktop = "$windir\AtlasDesktop"
New-Shortcut -Source "$desktop\9. Troubleshooting\Set services to defaults.cmd" -Destination "$desktop\6. Advanced Configuration\Services\Set services to defaults.lnk"