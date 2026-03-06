<#
 .DESCRIPTION:
    Installation Script for QuickBooks versions 2012+ downloaded from downloads.quickbooks.com
 .SYNOPSYS:
    This script extracts the QuickBooks .exe into a folder and then executes the same process that the setup.exe GUI interface performs by parsing the appropriate XML and INI inside the installation package and performing the same steps
 .AUTHOR:
    Dimitri Rodis
    DimitriR@integritasystems.com
    Integrita Systems LLC
    https://integritasystems.com

    Darren Kattan
    dkattan@immense.net
    Immense Networks, LLC
    https://www.immense.net

 .REVISION HISTORY:
    2020-11-18 Dimitri Rodis - Initial verified successful use of various editions and versions of QuickBooks 2017-2020 via ImmyBot
    2020-12-15 Darren Kattan - Added logic to log parser to specifically detect when failure occurred due to invalid license parameters
    2021-05-24 Dimitri Rodis - Added ability to convert to specific industry edition during initial installation (for Premier/Enterprise)
    2021-05-25 Dimitri Rodis - Added License Key Validation, installation will be aborted/prevented without a valid key. Forced script to run in 32-bit PowerShell for Validations to function unless $BypassLicenseCheck=$true
    2021-05-30 Dimitri Rodis - Increased size of allocated unmanaged string buffer to fix crashes/heap corruption. Apparently 256 bytes was not enough, increased to 1024 bytes.
                               Added code to extract ESGServices.dat directly from the QuickBooks.msi if it was not extracted into the temp folder during installation and copied successfully.
    2022-10-08 Dimitri Rodis - Added code to detect 64-bit versions (2022+, and Enterprise 22+) for the installation directory to be in $env:ProgramFiles
                               Added code to place server versions in their installation folders consistent with Intuit setup defaults
                               Added code to filter out the ABS PDF Driver installation if installing QuickBooks Server because it is not necessary
                               Added code to ignore ESGServices.dat for QuickBooks Server because it is unnecessary
                               Added code to resolve potential Database Manager/DNS Server port conflicts
    2023-04-03 Darren Kattan - Installation will throw a meaningful terminating error if the license is invalid
    2023-06-18 Dimitri Rodis - Very very recently, Intuit "broke" their extraction only methods for QuickBooks 2023/Ent 23. Switching to Extract-WithTool code to get around the broken extraction and setup.exe autolaunch
    2023-06-21 Dimitri Rodis - Added code to validate the lengths and patterns of the ProductNumber and LicenseNumber because someone submitted a ticket that the deployment didn't work, and they had a leading space in the LicenseNumber parameter.
    2024-02-01 Dimitri Rodis - Added code to alter the REBOOT=S to REBOOT=REALLYSUPPRESS msi commandline parameter sometimes present in the setup.ini
#>

#PARAMS FOR TESTING
#$InstallerFolder="D:\Downloads\QuickBooksPremier2020"
#$InstallOption="Desktop" # {Desktop,Server,DesktopServer}
#IndustrySpecificEdition="Professional Services" # {Accountant, Contractor, Manufacturing & Wholesale, Nonprofit, Professional Services, Retail}
#$LicenseNumber="XXXX-XXXX-XXXX-XXX"
#$ProductNumber="XXX-XXX"
#$BypassLicenseCheck=$false #Used to get around the license validation if needed
#$InstallerLogFile="D:\Downloads\QB.log"

#THIS IS HOW YOU FORCE THE SCRIPT TO RUN IN 32-BIT POWERSHELL
if ($env:Processor_Architecture -ne "x86" -and $BypassLicenseCheck -ne $true)   
{
    Write-Host "Thunking PowerShell $($env:Processor_Architecture) to x86"
    
    $result = (&"$env:windir\syswow64\windowspowershell\v1.0\powershell.exe" -noninteractive -noprofile -command $myinvocation.Mycommand.ScriptBlock -executionpolicy bypass)
    return $result
}
else{
    Write-Host "Running PowerShell $($env:Processor_Architecture)"
}

function Get-QBBinariesFromMSI {
    param (
        [cmdletbinding()]
        [switch]$Verbose,
        [string]$QuickBooksMSI,
        [string[]]$FileName=$null,
        [string[]]$BinaryName=$null,
        [string]$OutputPath=$null
    )
    function Get-Property ($Object, $PropertyName, [object[]]$ArgumentList) {
    return $Object.GetType().InvokeMember($PropertyName, 'Public, Instance, GetProperty', $null, $Object, $ArgumentList)
    }

    function Invoke-Method ($Object, $MethodName, $ArgumentList) {
    return $Object.GetType().InvokeMember($MethodName, 'Public, Instance, InvokeMethod', $null, $Object, $ArgumentList)
    }

    $msiOpenDatabaseModeReadOnly = 0
    $msiReadStreamAnsi = 2
    $Installer = New-Object -ComObject WindowsInstaller.Installer
    $Database = Invoke-Method $Installer 'OpenDatabase' @($QuickBooksMSI, $msiOpenDatabaseModeReadOnly)
    $QBBinaries = [PSCustomObject]@()

    $QBBinaryTable = Invoke-Method $Database 'OpenView' @('SELECT Binary.Name, QBBinary.FullPathToFilename, Binary.Data FROM QBBinary,Binary WHERE QBBinary.Binary_=Binary.Name')
    Invoke-Method $QBBinaryTable 'Execute'
    $BinaryRow = Invoke-Method $QBBinaryTable 'Fetch'
    while($BinaryRow) {
        $QBBinaryName = $BinaryRow.StringData(1)
        $QBBinaryFileName = ($BinaryRow.StringData(2) -replace '[\[].*[\]]')
        if((($FileName -ne $null) -and ($FileName -like $QBBinaryFileName -or $QBBinaryFileName -like $FileName)) -or (($BinaryName -ne $null) -and ($BinaryName -like $QBBinaryName -or $QBBinaryName -like $BinaryName))) {
            Write-Verbose "Matched [$QBBinaryFileName][$QBBinaryName] on [$FileName][$BinaryName]" -Verbose:($PSBoundParameters['Verbose'] -eq $true)
            $QBBinaries += [PSCustomObject]@{
                FileName = $QBBinaryFileName
                BinaryName = $QBBinaryName
                Binary = (Invoke-Method $BinaryRow "ReadStream" @(3, (Get-Property $BinaryRow "DataSize" 3), $msiReadStreamAnsi))
            }
        }
        $BinaryRow = Invoke-Method $QBBinaryTable 'Fetch'
    }
    Invoke-Method $QBBinaryTable 'Close' @()
    try { $null=[System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$Installer) } catch {}
    try { $null=[System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$QBBinaryTable)  } catch {}
    try { $null=[System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$Database) } catch {}
    $QBBinaryTable=$null
    $Database=$null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    if($OutputPath) {
        if((Test-Path -LiteralPath $OutputPath) -eq $false) {New-Item -ItemType Directory -Force -Path $OutputPath}
        if(Test-Path -LiteralPath $OutputPath) {
            $QBBinaries | % {$_.Binary | Set-Content -NoNewline (Join-Path $OutputPath $_.FileName)}
        }
    }

    return $QBBinaries 
}

function ValidateQBKeys {
    param (
        [cmdletbinding()]
        [switch]$Verbose,
        $QBooksPath,
        $LicenseKey,
        $ProductCode
    )

    $KeyFormatIsCorrect = $true
    if($LicenseKey.Length -ne 18 -or -not ($LicenseKey -match '(([0-9]{4}-){3}[0-9]{3})$')) { $KeyFormatIsCorrect = $false; Write-Host "The License Key $LicenseKey is not formatted correctly. (XXXX-XXXX-XXXX-XXX)" }
    if($ProductCode.Length -ne 7 -or -not ($ProductCode -match '([0-9]{3}-[0-9]{3})$')) { $KeyFormatIsCorrect = $false; Write-Host "The Product Code $ProductCode is not formatted correctly. (XXX-XXX)" }
    if($KeyFormatIsCorrect -eq $false) { return $false }

    $CleanUpTempFiles = $false
    $EntitlementClientDLLName = 'Intuit.Spc.Map.EntitlementClient.Install.dll'
    $ManifestECLName = 'manifest.ecml'
    $EntitlementClientDLL = (Join-Path $QBooksPath $EntitlementClientDLLName)
    $ManifestECML = (Join-Path $QBooksPath $ManifestECLName)
    $QuickBooksMSI = (Join-Path $QBooksPath 'QuickBooks.msi')

    if(-not ((Test-Path -PathType Leaf -LiteralPath $EntitlementClientDLL) -and  (Test-Path -PathType Leaf -LiteralPath $ManifestECML))) {
        Write-Verbose "Could not find both $EntitlementClientDLLName and $ManifestECLName in ""$QBooksPath"", attempting to look for QuickBooks.msi" -Verbose:($PSBoundParameters['Verbose'] -eq $true)
        if(Test-Path -PathType Leaf -LiteralPath $QuickBooksMSI) {
            Write-Verbose "Extracting $EntitlementClientDLLName and $ManifestECLName from $QuickBooksMSI" -Verbose:($PSBoundParameters['Verbose'] -eq $true)
            $EntitlementClientDLL = [System.IO.Path]::GetTempFileName()
            $ManifestECML = [System.IO.Path]::GetTempFileName()
            $QBBinaries = Get-QBBinariesFromMSI -Verbose:($PSBoundParameters['Verbose'] -eq $true) -QuickBooksMSI $QuickBooksMSI -BinaryName 'IbinaryEC?' #-FileName $EntitlementClientDLLName,$ManifestECLName
            $QBBinaries | ? {$_.FileName -eq $EntitlementClientDLLName} | % {$_.Binary | Set-Content -NoNewline $EntitlementClientDLL}
            $QBBinaries | ? {$_.FileName -eq $ManifestECLName} | % {$_.Binary | Set-Content -NoNewline $ManifestECML}
            $CleanUpTempFiles = $true
        }
        else {
            Write-Verbose "Could not find $EntitlementClientDLLName, $ManifestECLName, or QuickBooks.msi in '$QBooksPath'" -Verbose:($PSBoundParameters['Verbose'] -eq $true)
            return $null
        }
    }
    else {
        Write-Verbose "Using $EntitlementClientDLLName and $ManifestECLName located in '$QBooksPath'" -Verbose:($PSBoundParameters['Verbose'] -eq $true)
    }

    $LicenseKeyNoDashes = $LicenseKey.Replace('-','')
    $ProductCodeNoDashes = $ProductCode.Replace('-','')

    $DLLForSignature = $EntitlementClientDLL.Replace('\','\\')

    $signature = "[DllImport(`"$DLLForSignature`",EntryPoint=`"CheckLicenseNumberA`",ExactSpelling=true,CharSet=CharSet.Ansi)] public static extern int CheckLicenseNumber(string licenseNumber,out bool IsValid,IntPtr errorMessage, uint installerContext); [DllImport(`"$DLLForSignature`",EntryPoint=`"CheckOfferingCodeA`",ExactSpelling=true,CharSet=CharSet.Ansi)] public static extern int CheckOfferingCode(string entitlementManifestFileName, string offeringCode, out bool IsValid, IntPtr errorMessage, uint installerContext);"
    #GENERATE RANDOM NAME FOR THE TYPE (MUST START WITH A LETTER) BECAUSE IT CAN'T LOADED TWICE IN THE SAME POWERSHELL SESSION
    $QBECTypeName = "QBEC$((New-Guid).Guid.Replace('-',''))" 
    $QuickBooksEC = Add-Type -MemberDefinition $signature -PassThru -Name $QBECTypeName

    [bool]$bothChecksSucceeded = $false
    [bool]$isLicValid=$false;
    [System.IntPtr]$licMessagePtr=[System.Runtime.InteropServices.Marshal]::AllocHGlobal(1024);
    [System.Runtime.InteropServices.Marshal]::WriteByte($licMessagePtr,1023,0);
    $licCheck = $QuickBooksEC::CheckLicenseNumber($LicenseKeyNoDashes, [ref]$isLicValid, $licMessagePtr, 0)
    $licMessage = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($licMessagePtr)
    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($licMessagePtr)
    [bool]$isOCValid=$false;
    [System.IntPtr]$ocMessagePtr=[System.Runtime.InteropServices.Marshal]::AllocHGlobal(1024);
    [System.Runtime.InteropServices.Marshal]::WriteByte($ocMessagePtr,1023,0);
    $ocCheck = $QuickBooksEC::CheckOfferingCode($ManifestECML, $ProductCodeNoDashes, [ref]$isOCValid, $ocMessagePtr, 0)
    $ocMessage = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($ocMessagePtr)
    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($ocMessagePtr)

    $QuickBooksEC = $null

    if($CleanUpTempFiles -eq $true) {
        Remove-Item -Path $EntitlementClientDLL -Force -ErrorAction SilentlyContinue #UNFORTUNATELY THIS WILL LIKELY GET LEFT BEHIND
        Remove-Item -Path $ManifestECML -Force -ErrorAction SilentlyContinue
    }

    if($licCheck -eq 0 -and $ocCheck -eq 0) {
        $bothChecksSucceeded = $true
        if($isLicValid -eq $true) {Write-Host 'The License Key is VALID.'} else {Write-Host "The License Key $LicenseKey is NOT VALID."}
        if($isOCValid -eq $true)  {Write-Host 'The Product Key is VALID.'} else {Write-Host "The Product Code $ProductCode is NOT VALID."}
    }
    return ($bothChecksSucceeded -and $isLicValid -and $isOCValid)
}

#VARIABLES
$QBParams = ""
$INSTALLDIR="INSTALLDIR="
$INSTALLSERVERONLY="INSTALLSERVERONLY=1"
$QB_LICENSENUM="QB_LICENSENUM="
$QB_PRODUCTNUM="QB_PRODUCTNUM="
$UNIQUE_NAME="UNIQUE_NAME="
$ISW_LICENSENUM="ISW_LICENSENUM="
$ISW_PRODUCTNUM="ISW_PRODUCTNUM="
$INSTALLDESKTOPICONS="INSTALLDESKTOPICONS="
$QB_DBR_SETHOST="QB_DBR_SETHOST="
$QB_IS_SUBSCRIPTION="QB_IS_SUBSCRIPTION="
$PARENTAPP="PARENTAPP=INSTALLMANAGER"
#$QB_UPGRADE_REPAIR_1638="REINSTALL=ALL REINSTALLMODE=vemus QBCDREVINFO=2 INSTALLFLOW=2"

$Flavor=$null # {accountant, contractor, wholesale, nonprofit, professional, retail}
switch($IndustrySpecificEdition) 
{
    "General Business"          {$Flavor=""}
    "Accountant"                {$Flavor="accountant"}
    "Contractor"                {$Flavor="contractor"}
    "Manufacturing & Wholesale" {$Flavor="wholesale"}
    "Nonprofit"                 {$Flavor="nonprofit"}
    "Professional Services"     {$Flavor="professional"}
    "Retail"                    {$Flavor="retail"}
    default                     {$Flavor=$null}
}

$64bit = $false

if($SoftwareName -match '\d{4}') #Year
{ 
    $ServerFolder = "QuickBooks $($Matches[0])"
    if([int]$Matches[0] -ge 2022) 
    {
        $64bit = $true
    }
}
elseif($SoftwareName -match '\d{2}') #Enterprise
{ 
    $ServerFolder = "QuickBooks Enterprise Solutions $($Matches[0]).0"
    if([int]$Matches[0] -ge 22) 
    {
        $64bit = $true
    }
}

if($64bit -eq $true) 
{
    $ProgramFiles = $($env:ProgramFiles)
}
else 
{
    $ProgramFiles = (${env:ProgramFiles(x86)}, ${env:ProgramFiles} -ne $null)[0]
}


Function ParseIniFile ($file) {
    $ini = @{}

    # Create a default section if none exist in the file. Like a java prop file.
    $section = "NO_SECTION"
    $ini[$section] = @{}

    switch -regex -file $file {
        "^\[(.+)\]$" {
        $section = $matches[1].Trim()
        $ini[$section] = @{}
        }
        "^\s*([^#].+?)\s*=\s*(.*)" {
        $name,$value = $matches[1..2]
        # skip comments that start with semicolon:
        if (!($name.StartsWith(";"))) {
            $ini[$section][$name] = $value.Trim()
        }
        }
    }
    $ini
}

#DR 20230618 Commenting this, Intuit broke the extraction args in Desktop 2023/Ent 23, using extract-withtool code
<#
$ExtractionFolder = $InstallerFolder
mkdir $ExtractionFolder -Force | Out-Null
Write-Host "Extracting $InstallerFile to $ExtractionFolder"
$InstallerArgs = @"
/silent /e /f "$ExtractionFolder"
"@
Start-Process -Wait $InstallerFile -ArgumentList $InstallerArgs
#>

#Extract-WithTool Params
$Tool = "7za"
$ExtractionFolder = $InstallerFolder
$Archive = $InstallerFile
#Extract-WithTool
mkdir $ExtractionFolder -Force | Out-Null
$ToolPath = Join-Path $ExtractionFolder "$Tool.exe"
Write-Host "Downloading $Tool to $ToolPath"
(New-Object System.Net.WebClient).DownloadFile("https://immybot.blob.core.windows.net/software/Tools/$Tool.exe",$ToolPath)

$ArgumentList = switch($Tool) {
    '7za' {"x ""$Archive"" -o""$ExtractionFolder"" -aoa"}
    'Unrar' {"x -o+ ""$Archive"" ""$ExtractionFolder"""}
}
Write-Host "Extracting $Archive to $ExtractionFolder"

Start-Process -Wait $ToolPath -ArgumentList $ArgumentList
#Extract-WithTool END

$xmlFile = Join-Path $ExtractionFolder "QBooks\Framework.xml"
$iniFile = Join-Path $ExtractionFolder "QBooks\setup.ini"

$iniData = ParseIniFile($iniFile)
if($InstallOption -ne "Server") 
{
    $QBTARGETFOLDER = (Join-Path (Join-Path $ProgramFiles Intuit) $iniData["Contents"]["Product"])
}
else
{
    $QBTARGETFOLDER = (Join-Path (Join-Path $ProgramFiles Intuit) $ServerFolder)
}

$INSTALLDIR += '"' + $QBTARGETFOLDER  + '"'
$Sku=$iniData["Contents"]["SKU"].Substring(2).ToLower()

#DR 20230621 Validate the patterns of the keys
if($ProductNumber) {
    if($ProductNumber -notmatch '^\d{3}-\d{3}$') {
        if ($ProductNumber -match '^\d{6}$'){
            $ProductNumber = $ProductNumber.Insert(3, '-')
        } else {
            Throw "ProductNumber is not in the correct format: XXX-XXX"
        }
    }
}
if($LicenseNumber) {
    if($LicenseNumber -notmatch '^(?:\d{4}-){3}\d{3}$') {
        if($LicenseNumber -match '^\d{15}$'){
            $LicenseNumber = $LicenseNumber.Insert(4, '-').Insert(9, '-').Insert(14, '-')
        } else {
            Throw "LicenseNumber is not in the correct format: XXXX-XXXX-XXXX-XXX"
        }
    }
}

if($BypassLicenseCheck -ne $true)
{
    $QBooksPath = Join-Path "$ExtractionFolder" 'QBooks'
    if(!(ValidateQBKeys -QBooksPath $QBooksPath -LicenseKey "$LicenseNumber" -ProductCode "$ProductNumber"))
    {
        Write-Host "Aborting Installation - License/Product Key Invalid"
        return $false
    }
}

switch($InstallOption) {
    "Server" {
        $INSTALLDESKTOPICONS+="0"
        $QB_DBR_SETHOST+="1"
    }
    "Desktop"{
        $INSTALLSERVERONLY=""
        $QB_LICENSENUM+=$LicenseNumber
        $QB_PRODUCTNUM+=$ProductNumber
        $UNIQUE_NAME+=$Sku
        $INSTALLDESKTOPICONS+="1"
        $QB_DBR_SETHOST+="0"
    }
    "DesktopServer" {
        $INSTALLSERVERONLY=""
        $QB_LICENSENUM+=$LicenseNumber
        $QB_PRODUCTNUM+=$ProductNumber
        $UNIQUE_NAME+=$Sku
        $INSTALLDESKTOPICONS+="1"
        $QB_DBR_SETHOST+="1"
    }
}

if("bel","proplus","superproplus" -contains $Sku ) {
    $QB_IS_SUBSCRIPTION+="1" #ENTERPRISE, PREMIER PLUS=1
}
else {
    $QB_IS_SUBSCRIPTION+="0" #ALL OTHERS=0
}

Remove-Item $InstallerLogFile -Force -ErrorAction Ignore
$QBParams = @($INSTALLDIR, $INSTALLSERVERONLY, $QB_LICENSENUM, $QB_PRODUCTNUM, $UNIQUE_NAME, $ISW_LICENSENUM, $ISW_PRODUCTNUM, $INSTALLDESKTOPICONS, $QB_DBR_SETHOST, $QB_IS_SUBSCRIPTION, $PARENTAPP)
$QBParams += "/l*v `"$InstallerLogFile`""
$QBParams = $QBParams -Join " "
[xml]$xml = get-content $xmlFile

$Components = @()
[int]$ComponentNumberOffset = 0
ForEach($Component in $xml.InstallerFramework.Components.GetEnumerator())
{
    if($Component.RequiredComponent -match "TRUE" -and $Component.Suspendcomponent -notmatch "Suspend")
    {
        $IsInstalled=$false
        $RegPath=""
        $RegStringValue=""
        $RegValue=""
        $Installer = ""
        $Command = $null
        $ComponentName = $Component.Name.Trim()
        [int]$ComponentNumber = [int]$Component.Number + [int]$ComponentNumberOffset

        ForEach($node in $Component.ChildNodes)
        {
            if($node.HasAttributes -eq $true -and $node.name -eq "Registry")
            {
                $RegPath = $node.'#text'.Trim()
                if($RegPath -eq $null -or $RegPath -eq "" -or $RegPath -eq "None") {$RegPath=""}
                else 
                {
                    if($node.Item("RegistryStringValue") -ne $null -and $node.RegistryStringValue.InnerText -ne $null) {$RegStringValue = $node.RegistryStringValue.InnerText.Trim()}
                    #$RegValue = $node.RegistryValue.InnerText.Trim()
                    
                    if($RegValue -eq "None") {$RegValue=""}

                    if((Test-Path Registry::$RegPath) -eq $true)
                    {
                        if((Get-Item -ErrorAction Ignore -Path Registry::$RegPath).GetValue($RegStringValue) -ne $null)
                        {
                            $IsInstalled=$true
                            break
                        }
                    }
                }
            }
        }

        if($IsInstalled -eq $false)
        {
            $Installer = $null
            $CommandArgs = ""
            ForEach($prop in $Component.InstallLocation.Property)
            {
                if($prop.location -eq "Local" -and $prop.InnerText -ne $null)
                {
                    $Installer = Join-Path $ExtractionFolder $prop.InnerText.Trim()
                    break
                }
            }

            $Command = $Component.Command
            if($Installer -ne $null -and $Command -ne $null)
            {
                if($Command.GetType().ToString() -match "System.Xml.XmlElement")
                {
                    $CommandArgs = $Component.Command.InnerText.Trim()
                }
                else 
                {
                    $CommandArgs = $Command.Trim()
                }

                if($CommandArgs -eq "None") {
                    $CommandArgs=""
                }
                else {
                    $CommandArgs = $CommandArgs -replace "REBOOT=\S*","REBOOT=REALLYSUPPRESS"
                }
            }

            if($Installer -ne $null)
            {
                if($Installer -match "QuickBooks.msi")
                {  
                    $ComponentNumberOffset = 1000-$ComponentNumber
                    $ComponentNumber = 1000
                    $CommandArgs = @($CommandArgs, $QBParams) -Join " "
                    $CommandArgs = "/i `"$Installer`" /passive $CommandArgs"
                    $Installer = "msiexec"
                    if($InstallOption -eq "Server")
                    {
                        $ComponentName = $ComponentName.Replace("Desktop","Server")
                    }
                }
            }
        }

        $Components += [PSCustomObject]@{
            Number = [int]$ComponentNumber
            Name = $ComponentName
            IsInstalled = $IsInstalled
            Command = $Installer
            CommandArgs = $CommandArgs
        }

    }
  
}

$InstalledQuickBooksMSI = (Join-Path -Path ($QBTARGETFOLDER) -ChildPath "components\pconfig\QuickBooks.msi")

if($Flavor -ne $null -and "bel","superpro","superproplus" -contains $Sku)
{
    $SkuFrom = $Sku
    $SkuTo = $null
    if($Sku -eq "bel") 
    {   
        if($Flavor -eq "accountant") 
        {
            $SkuTo="belacct"
        }
        else
        {
            $SkuTo="bel$Flavor" # "bel" (alone) is the "General Business" case
        }
    }
    elseif($Sku -eq "superpro")
    {
        $SkuTo=$Flavor
        if($Flavor -eq "") { # "General Business" case
            $SkuTo = "superpro"
        }
    }
    if($SkuTo -ne $null)
    {
        $CommandArgs = "/i ""$InstalledQuickBooksMSI"" QB_MORPH=1 QBUSEEC=1  QB_PRODUCTNUMFROM=$ProductNumber QB_LICENSENUMFROM=$LicenseNumber QB_PRODUCTNUM=$ProductNumber QB_LICENSENUM=$LicenseNumber QB_INSTALLFLAVORFROM=$SkuFrom QB_INSTALLFLAVOR=$SkuTo CKBOX_GDS=0 $QB_IS_SUBSCRIPTION /qn"
        $Components += [PSCustomObject]@{
            Number = [int]2000
            Name = "Transform QuickBooks to Edition: $IndustrySpecificEdition"
            IsInstalled = $false
            Command = "msiexec"
            CommandArgs = $CommandArgs
        }
    }
}

if($InstallOption -eq "Server") #Filter out the ABS PDF Driver, not needed for server installs
{
    $Components = $Components | ?{$_.Name -ne "ABS PDF Driver"}
}

$Components = $Components | Sort-Object -Property Number

$Components | Select-Object Name,IsInstalled | ft

$Components | ?{$_.IsInstalled -eq $false} | % {
    Write-Progress "Installing $($_.Name) ..."
    if($_.CommandArgs) 
    {        
        Write-Host "$($_.Command) $($_.CommandArgs)"
        $Process = Start-Process $_.Command -ArgumentList "$($_.CommandArgs)" -PassThru
        $GrabFile = $null
        if($($_.CommandArgs) -match "QuickBooks.msi" -and $InstallOption -ne "Server" -and -not (Test-Path -PathType Leaf -Path (Join-Path (Join-Path -Path ($QBTARGETFOLDER) -ChildPath "\Components\Payroll") "ESGServices.dat")))
        {
            $GrabFile = (Join-Path $env:Temp "ESGServices.dat")
            while($Process.HasExited -eq $false -and ((Test-Path $GrabFile) -eq $false -or (Get-Item $GrabFile).length -eq 0)) { Start-Sleep 1 } #Not all QB versions might have this file, so we don't want the script to hang.
            if((Test-Path $GrabFile) -eq $true) 
            {
                try {
                    Copy-Item -Path $GrabFile -Destination "$Grabfile.grabbed" -Force -ErrorAction SilentlyContinue
                }
                catch {
                    $GrabFile = $null #Could not grab it
                }
            }
            else 
            {
                $Grabfile=$null #File never created/seen.
            }
            $dest = (Join-Path (Join-Path -Path ($QBTARGETFOLDER) -ChildPath "\Components\Payroll") "ESGServices.dat")
            $Process.WaitForExit()
            if($Grabfile -ne $null)
            {
                try { Copy-Item -Path "$Grabfile.grabbed" -Destination $dest -Force -ErrorAction SilentlyContinue } catch {}
                try { Remove-Item -Path "$Grabfile.grabbed" -Force -ErrorAction SilentlyContinue } catch {}
            }
            else 
            {
                $QBBinaries = Get-QBBinariesFromMSI -QuickBooksMSI $InstalledQuickBooksMSI -FileName "ESGServices.dat"
                $QBBinaries | ? {$_.FileName -eq "ESGServices.dat"} | % {$_.Binary | Set-Content -NoNewline $dest}
            }
        }
        else
        {
            $Process.WaitForExit()
        }
    }
    else 
    {
        Write-Host "$($_.Command)"
        $Process = Start-Process $_.Command -PassThru
        $Process.WaitForExit()
    }
    Write-Host "Exit Code: $($Process.ExitCode)"
    $QBKeyCodeValid = $true
    if($Process.ExitCode -ne 0 -and $Process.ExitCode -ne 1638) #1638 means the product (or another version that can't coexist with this one) is already installed. This is the normal return code for a couple of the components.
    {
        if (Test-Path $InstallerLogFile -PathType leaf)
        {
            Write-Host "InstallerLogFile=$InstallerLogFile"
            $LogContent = (Get-Content $InstallerLogFile) -Join "`r`n"
            if($LogContent -match 'Property\(S\): QbKeyCodeValid = (.*)')
            {
                $QBKeyCodeValid = $Matches[1]
                Write-Host "Key Code: $QBKeyCodeValid"
                if($QBKeyCodeValid -eq "NotValid")
                {
                    throw "Installation failed due to invalid LicenseNumber or ProductNumber"
                }
            }
            else
            {
                Write-Host ($LogContent | select -last 200 | Out-String)
            }
        }
    }
}
if($InstallOption -eq "Server") {
    $QBServerPortInfoFile = "$($env:ProgramData)\Intuit\QuickBooks\QBGLOBALAPPCONFIG.INI"
    #New-Item -Path "$($env:ProgramData)\Intuit\QuickBooks" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    #$QBBinaries = Get-QBBinariesFromMSI -QuickBooksMSI $InstalledQuickBooksMSI -FileName "QBGLOBALAPPCONFIG.INI"
    #$QBBinaries | ? {$_.FileName -eq "QBGLOBALAPPCONFIG.INI"} | % {$_.Binary | Set-Content -NoNewline $QBServerPortInfoFile}
    try {
        $QBServerPortInfo = ParseIniFile -file $QBServerPortInfoFile
        $StartPort = $QBServerPortInfo.QBDBPortFinder.StartPortNumber
        $NumberOfPorts = $QBServerPortInfo.QBDBPortFinder.Range
    }
    catch {
        Write-Warning "Unable to get Port/Range data from $QBServerPortInfoFile"
    }
    if($null -ne $StartPort -and $null -ne $NumberOfPorts) {
        #http://www.devonstephens.com/quickbooks-database-manager-conflicting-dns-server/
        $DNSService = Get-Service "DNS Server" -ErrorAction SilentlyContinue
        if($null -ne $DNSService) {
            $DNSService | Stop-Service -Force -ErrorAction SilentlyContinue | Out-Null
        }
        $Process = Start-Process "netsh" -ArgumentList "int ipv4 add excludedportrange protocol=udp startport=$StartPort numberofports=$NumberOfPorts" -Wait -PassThru
        if($null -ne $DNSService) {
            $DNSService | Start-Service -ErrorAction SilentlyContinue | Out-Null
        }
        #$Components += [PSCustomObject]@{
        #    Number = [int]998
        #    Name = "Resolve Potential Database Manager/DNS Server Port Conflict"
        #    IsInstalled = $false
        #    Command = "netsh"
        #    CommandArgs = "int ipv4 add excludedportrange protocol=udp startport=$StartPort numberofports=$NumberOfPorts"
        #}
        #$Components += [PSCustomObject]@{
        #    Number = [int]999
        #    Name = "Restart DNS Server"
        #    IsInstalled = $false
        #    Command = "powershell"
        #    CommandArgs = '-command "Restart-Service DNS -Force"'
        #}
    }
}
