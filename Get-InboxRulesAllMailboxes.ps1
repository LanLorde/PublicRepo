<#
.SYNOPSIS
  Retrieves inbox rules for all mailboxes in organization.
.OUTPUTS
  Outputs file to %UserProfile%\AppData\Local\Temp\
  File is a .CSV named after compnay ran against and the time ran.
.NOTES
  Version:        1.0
  Author:         Brian Klawitter
  Creation Date:  <Date>
  Purpose/Change: Initial script development
  Company:        Impact Networking
  
.EXAMPLE
  .\Get-InboxRulesAllMailboxes.ps1
#>


#   Generate File Name Data
$Date = Get-Date
$Name = ("Report", $Date.Month, $Date.Day, $Date.Year, $Date.Hour , $Date.Minute, $Date.Second) -join "."




# Test Connection to Exhcange Online Tenancy

Try {
    $ExOn = (Get-OrganizationConfig -ErrorAction Stop).DisplayName
    Write-Host "You're currently connected to"$Exon" Exhcange Online Module" -BackgroundColor DarkGreen

}
Catch {
    Write-Host "You are not connected to any Exhcange Online Tenants" -BackgroundColor Red
    Write-Host "Please use Connect-ExhcangeOnline or download the Exchange Online Management module" -BackgroundColor Red

}


# Main logic

# Creates Output ojbect list that allows for the creation of an output file
$Report = [System.Collections.Generic.List[Object]]::new() 
# Retrieves All Mailboxes 
$Mailboxes = Get-Mailbox -ResultSize Unlimited | Select-Object UserPrincipalName,DisplayName
ForEach ($Mailbox in $Mailboxes) {

    $Rules = Get-InboxRule -Mailbox $Mailbox.UserPrincipalName | Select-Object Name,Description
    ForEach ($Rule in $Rules) {

        $ReportLine = [PSCustomObject] @{
            User     = $Mailbox.DisplayName
            RuleName = $Rule.Name -join ";"
            Rule     = $Rule.Description -join ";"

        }
        $Report.Add($ReportLine)
    }
}



#   Save report to .CSV file
$Report | Sort-Object Name | Export-CSV -NoTypeInformation -Encoding UTF8 $ENV:TEMP\$Name.csv
Write-Host "The Report is located in $ENV:TEMP\$Name.csv"