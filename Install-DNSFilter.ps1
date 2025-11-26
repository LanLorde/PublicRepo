
<#
.SYNOPSIS
Downloads DNSFilter agent MSI and installs it silently.
.DESCRIPTION
This script downloads the DNSFilter agent installer to C:\Temp and runs msiexec with the provided key.
.EXAMPLE
.\Install-DNSFilter.ps1 -Key "YOUR-DNSFILTER-KEY"
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$Key
)

# Ensure C:\Temp exists
$DownloadPath = "C:\Temp"
if (-not (Test-Path $DownloadPath)) {
    New-Item -ItemType Directory -Path $DownloadPath | Out-Null
}

# Define file and URL
$InstallerUrl = "https://download.dnsfilter.com/User_Agent/Windows/DNS_Agent_Setup.msi"
$InstallerFile = Join-Path $DownloadPath "DNS_Agent_Setup.msi"

Write-Host "Downloading DNSFilter installer..."
try {
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerFile -UseBasicParsing
    Write-Host "Download complete: $InstallerFile"
} catch {
    Write-Error "Failed to download installer: $_"
    exit 1
}

# Install silently
Write-Host "Installing DNSFilter agent..."
$Arguments = "/qn /i `"$InstallerFile`" NKEY=`"$Key`" TRAYICON=`"disabled`""
$Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait -PassThru

if ($Process.ExitCode -eq 0) {
    Write-Host "DNSFilter agent installed successfully."
} else {
    Write-Error "Installation failed with exit code $($Process.ExitCode)"
}
