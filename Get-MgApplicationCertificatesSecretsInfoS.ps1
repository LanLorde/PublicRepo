function Get-MgApplicationCertificatesSecretsInfoS {

    <#
    .SYNOPSIS
        Returns a list of Azure App Registration with information about their certificas and secrets.

    .DESCRIPTION
        Get-MgApplicationCertificatesSecretsInfoS is a function that returns a list of all or selected Azure App 
        Registration with information about their certificas and/or secrets.

    .PARAMETER Entity
        What to include in the returned list.
        Value: "Certificates", "Secrets" or "Certificates,Secrets"
        Default value: "Certificates,Secrets"

    .PARAMETER Filter
        Filter to include in Get-MgApplication.
        Example: "DisplayName eq 'Connect to Dynamics'"
        Example: "AppId eq '39b09640-ec3e-44c9-b3de-f52db4e1cf66'"

    .EXAMPLE
         Get-MgApplicationCertificatesSecretsInfoS | FT -AutoSize
         Returns all Azure Application Registrations that have certificates, secrets or both.

    .EXAMPLE
         Get-MgApplicationCertificatesSecretsInfoS | Where {$_.DaysLeft -lt 0} | FT -AutoSize
         Returns all Azure Application Registrations that have certificates, secrets or both with Daysleft less than zero, expired.

    .EXAMPLE
         Get-MgApplicationCertificatesSecretsInfoS | Export-CSV -NoTypeInformation -Path "C:\Temp\AzureAppRegCertSecretsInfo.csv"
         Returns all Azure Application Registrations that have certificates, secrets or both and save them to CSV file.

    .EXAMPLE
         Get-MgApplicationCertificatesSecretsInfoS -Verbose -Entity "Certificates" -Filter "DisplayName eq 'Connect to Dynamics'" | FT -AutoSize
         Returns certificates for Azure Application Registration named 'Connect to Dynamics'.

    .EXAMPLE
         "Secrets" | Get-MgApplicationCertificatesSecretsInfoS -Verbose -Filter "DisplayName eq 'Connect to Dynamics'" | FT -AutoSize
         Returns Secrets for Azure Application Registration named 'Connect to Dynamics'.

    .INPUTS
        String

    .OUTPUTS
        PSCustomObject
        ApplicationName, ApplicationID, Type, Description, StartDate, EndDate, DaysLeft, KeyId and Owners

    .NOTES
        Author:  Saad Khamis
        Website: https://saadkhamis.com/azure-app-registrations-export-certificates-and-secrets-details/
    #>

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
} Get-MgApplicationCertificatesSecretsInfoS | Export-CSV -NoTypeInformation -Path C:\AAD_Reports\AHV_AppRegistrations.csv