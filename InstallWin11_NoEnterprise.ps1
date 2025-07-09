<#
$dir = "C:\Temp"
$webClient = New-Object System.Net.WebClient
$url = "https://go.microsoft.com/fwlink/?linkid=2156295"
$file = "$($dir)\MediaCreationTool.exe"
$webClient.DownloadFile($url,$file)
Start-Process -FilePath $file -ArgumentList "/auto upgrade /quietinstall /eula accept" -verb runas
#>



$workingdir = "C:\temp"
$url = "https://go.microsoft.com/fwlink/?linkid=2171764"
$file = "$($workingdir)\Win11Upgrade.exe"

If(!(test-path $workingdir))
{
New-Item -ItemType Directory -Force -Path $workingdir
}

Invoke-WebRequest -Uri $url -OutFile $file

Start-Process -FilePath $file -ArgumentList "/Install /QuietInstall /SkipEULA" -verb RunAs
