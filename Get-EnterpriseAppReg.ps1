$DirectoryPath = "C:\AAD_Reports\"

if (-not (Test-Path -Path $DirectoryPath -PathType Container)) {
    New-Item -Path $DirectoryPath -ItemType Directory
}

$Client = Read-Host "Enter 3/4 digit client code"

function Get-EnterpriseAppRegs {
Connect-MgGraph -Scopes 'Application.Read.All' -NoWelcome

$Applications = Get-MgServicePrincipal -all
$Logs = @()

$Messages = @{
    ExpirationDays = @{
        Info   = 'Filter the applications to log by the number of days until their secrets expire.'
        Prompt = 'Enter the number of days until the secrets expire as an integer.'
    }
    AlreadyExpired = @{
        Info   = 'Would you like to see Applications with already expired secrets as well?'
        Prompt = 'Enter Yes or No'
    }
    DurationNotice = @{
        Info = @(
            'The operation is running and will take longer the more applications the tenant has...'
            'Please wait...'
        ) -join ' '
    }
    Export = @{
        Info = 'Where should the CSV file export to?'
        Prompt = 'Enter the full path in the format of <C:\Users\<USER>\Desktop\Users.csv>'
    }
}

$DaysUntilExpiration = "182"

$IncludeAlreadyExpired = "Yes"

$Now = Get-Date

Write-Host $Messages.DurationNotice.Info -ForegroundColor yellow

foreach ($App in $Applications) {
    $AppName = $App.DisplayName
    $AppID   = $App.Id
    $ApplID  = $App.AppId

$AppCreds = Get-MgServicePrincipal -ServicePrincipalId $AppID |
        Select-Object PasswordCredentials, KeyCredentials

$Secrets = $AppCreds.PasswordCredentials
    $Certs   = $AppCreds.KeyCredentials

foreach ($Secret in $Secrets) {
        $StartDate  = $Secret.StartDateTime
        $EndDate    = $Secret.EndDateTime
        $SecretName = $Secret.DisplayName

$Owner    = Get-MgServicePrincipalOwner -ServicePrincipalId $App.Id
        $Username = $Owner.AdditionalProperties.userPrincipalName -join ';'
        $OwnerID  = $Owner.Id -join ';'

if ($null -eq $Owner.AdditionalProperties.userPrincipalName) {
            $Username = @(
                $Owner.AdditionalProperties.displayName
                '**<This is an Application>**'
            ) -join ' '
        }

if ($null -eq $Owner.AdditionalProperties.displayName) {
            $Username = '<<No Owner>>'
        }

$RemainingDaysCount = $EndDate - $Now |
            Select-Object -ExpandProperty Days

if ($IncludeAlreadyExpired -eq 'No') {
            if ($RemainingDaysCount -le $DaysUntilExpiration -and $RemainingDaysCount -ge 0) {
                $Logs += [PSCustomObject]@{
                    'ApplicationName'        = $AppName
                    'ApplicationID'          = $ApplID
                    'Secret Name'            = $SecretName
                    'Secret Start Date'      = $StartDate
                    'Secret End Date'        = $EndDate
                    'Certificate Name'       = $Null
                    'Certificate Start Date' = $Null
                    'Certificate End Date'   = $Null
                    'Owner'                  = $Username
                    'Owner_ObjectID'         = $OwnerID
                }
            }
        } elseif ($IncludeAlreadyExpired -eq 'Yes') {
            if ($RemainingDaysCount -le $DaysUntilExpiration) {
                $Logs += [pscustomobject]@{
                    'ApplicationName'        = $AppName
                    'ApplicationID'          = $ApplID
                    'Secret Name'            = $SecretName
                    'Secret Start Date'      = $StartDate
                    'Secret End Date'        = $EndDate
                    'Certificate Name'       = $Null
                    'Certificate Start Date' = $Null
                    'Certificate End Date'   = $Null
                    'Owner'                  = $Username
                    'Owner_ObjectID'         = $OwnerID
                }
            }
        }
    }

foreach ($Cert in $Certs) {
        $StartDate = $Cert.StartDateTime
        $EndDate   = $Cert.EndDateTime
        $CertName  = $Cert.DisplayName

$RemainingDaysCount = $EndDate - $Now |
            Select-Object -ExpandProperty Days

$Owner    = Get-MgServicePrincipalOwner -ServicePrincipalId $App.Id
        $Username = $Owner.AdditionalProperties.userPrincipalName -join ';'
        $OwnerID  = $Owner.Id -join ';'

if ($null -eq $Owner.AdditionalProperties.userPrincipalName) {
            $Username = @(
                $Owner.AdditionalProperties.displayName
                '**<This is an Application>**'
            ) -join ' '
        }
        if ($null -eq $Owner.AdditionalProperties.displayName) {
            $Username = '<<No Owner>>'
        }

if ($IncludeAlreadyExpired -eq 'No') {
            if ($RemainingDaysCount -le $DaysUntilExpiration -and $RemainingDaysCount -ge 0) {
                $Logs += [pscustomobject]@{
                    'ApplicationName'        = $AppName
                    'ApplicationID'          = $ApplID
                    'Secret Name'            = $Null
                    'Certificate Name'       = $CertName
                    'Certificate Start Date' = $StartDate
                    'Certificate End Date'   = $EndDate
                    'Owner'                  = $Username
                    'Owner_ObjectID'         = $OwnerID
                    'Secret Start Date'      = $Null
                    'Secret End Date'        = $Null
                }
            }
        } elseif ($IncludeAlreadyExpired -eq 'Yes') {
            if ($RemainingDaysCount -le $DaysUntilExpiration) {
                $Logs += [pscustomobject]@{
                    'ApplicationName'        = $AppName
                    'ApplicationID'          = $ApplID
                    'Certificate Name'       = $CertName
                    'Certificate Start Date' = $StartDate
                    'Certificate End Date'   = $EndDate
                    'Owner'                  = $Username
                    'Owner_ObjectID'         = $OwnerID
                    'Secret Start Date'      = $Null
                    'Secret End Date'        = $Null
                }
            }
        }
    }
}

Write-Host "File is being saved..." -ForegroundColor Green
$Path = "$DirectoryPath\${Client}_Certs.csv"
$Logs | Export-Csv $Path -NoTypeInformation -Encoding UTF8
}


function Get-MgApplicationCertificatesSecretsInfoS {

    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Entity = "Certificates,Secrets",
        [string] $Filter = $null
    )

    BEGIN {
        $Param = if ($Filter -eq $null) { @{ "All" = $true } } else { @{ Filter = $Filter } }
        $Apps = Get-MgApplication @Param  | Sort-Object DisplayName
        $now = get-date
        $Returns = @()
    }
    PROCESS {
        $Entity = $Entity.ToLower()
        $Entity = $Entity.Replace("certificates", "KeyCredentials")
        $Entity = $Entity.Replace("secrets", "PasswordCredentials")
        Write-Verbose -Message ""
        ForEach ($App in $Apps) { 
            Write-Verbose -Message "$($App.DisplayName)"
            $owner = Get-MgApplicationOwner -ApplicationId $App.Id
            foreach ($EntityName in $Entity.Split(",")) {
                Write-Verbose -Message "`tProcessing $Type"
                $Type = if ($EntityName -eq "KeyCredentials") { "Certificate" } else { "Secret" }
                foreach ($EntityObj in $App.($EntityName)) {
                    Write-Verbose -Message "`t`tName [$($EntityObj.DisplayName)], Id [$($EntityObj.KeyId)]"
                    $DaysLeft = ($EntityObj.EndDateTime - $now).Days
                    $Return = New-Object System.Object
                    $Return | Add-Member -MemberType NoteProperty -Name "ApplicationName" -Value $App.DisplayName
                    $Return | Add-Member -MemberType NoteProperty -Name "ApplicationID" -Value $App.Id
                    $Return | Add-Member -MemberType NoteProperty -Name "Type" -Value $Type
                    $Return | Add-Member -MemberType NoteProperty -Name "Description" -Value $EntityObj.DisplayName
                    $Return | Add-Member -MemberType NoteProperty -Name "StartDate" -Value $EntityObj.StartDateTime
                    $Return | Add-Member -MemberType NoteProperty -Name "EndDate" -value $EntityObj.EndDateTime
                    $Return | Add-Member -MemberType NoteProperty -Name "DaysLeft" -value $DaysLeft
                    $Return | Add-Member -MemberType NoteProperty -Name "KeyId" -value $EntityObj.KeyId
                    $Return | Add-Member -MemberType NoteProperty -Name "Owners" -Value $owner.AdditionalProperties.userPrincipalName
                    $Returns += $Return
                }
            }
        }
    }
    END {
        return ($Returns)
    }
} 


Get-EnterpriseAppRegs 
Get-MgApplicationCertificatesSecretsInfoS | Export-CSV -NoTypeInformation -Path $DirectoryPath\$Client"_AppRegs.csv"
Disconnect-Graph