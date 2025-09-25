<#
$dir = "C:\Temp"
$webClient = New-Object System.Net.WebClient
$url = "https://go.microsoft.com/fwlink/?linkid=2156295"
$file = "$($dir)\MediaCreationTool.exe"
$webClient.DownloadFile($url,$file)
Start-Process -FilePath $file -ArgumentList "/auto upgrade /quietinstall /eula accept" -verb runas
#>


<#
$workingdir = "C:\temp"
$url = "https://go.microsoft.com/fwlink/?linkid=2171764"
$file = "$($workingdir)\Win11Upgrade.exe"

If(!(test-path $workingdir))
{
New-Item -ItemType Directory -Force -Path $workingdir
}

Invoke-WebRequest -Uri $url -OutFile $file

Start-Process -FilePath $file -ArgumentList "/Install /QuietInstall /SkipEULA" -verb RunAs
#>

### Above are previously working PoCs that have since stopped working. ###

# Directory where Windows upgrade assistant exe will be downloaded.

$dir = 'C:\temp\24H2'

#This line will create the directory if it doesnt exist.

mkdir $dir

#This line will be used to download the file from the internet.

$webClient = New-Object System.Net.WebClient

#URL where Windows 11 upgrade assistant is hosted.

$url = 'https://go.microsoft.com/fwlink/?linkid=2171764'

#Variable that points to the upgrade exe.

$file = "$($dir)\Win11Upgrade.exe"

#This will grab the upgrade file from microsoft and save it to the specified file path in line 10.

$webClient.DownloadFile($url,$file)

# This will run Windows 11 Assistant and install it quietly, skips user license agreement, upgrades automatically

# And copies the logs to the file path provided in line 3.

Start-Process -FilePath $file -ArgumentList '/quietinstall /auto upgrade /NoRestartUI /finalize /skipeula /copylogs $dir'