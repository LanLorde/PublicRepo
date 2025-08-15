<#
.SYNOPSIS
  Gather data on Shared Mailboxes
.DESCRIPTION
  Shared Mailbox Permissions
.INPUTS
  None
.OUTPUTS
  Outputs stored 
.NOTES
  Version:        1.0
  Author:         BK
  Creation Date:  8/15/25
  Purpose/Change: Gather All Mailboxs and their respective permissions
  
#>

# Exchange
Try {
    $ExOn = (Get-OrganizationConfig -ErrorAction Stop).DisplayName


}
Catch {
    Write-Host "You need to connect to the Exchange Online Module before running this..." -BackgroundColor Red

}


$Report = [System.Collections.Generic.List[Object]]::new() 
$Mailboxes = Get-EXOMailbox
ForEach ($Mailbox in $Mailboxes){

    $Access = Get-EXOMailboxPermission -Identity $Mailbox.Identity

    $ReportLine = [PSCustomObject] @{
    Mailbox = $Mailbox.DisplayName
    MailboxType = $Mailbox.RecipientTypeDetails
    User = $Access.User -join ","
    Access = $Access.AccessRights -join ","


    }
    $Report.Add($ReportLine)

}




$Date = Get-Date
$Name = ("Mailbox-Permission-Report", $Date.Month, $Date.Day, $Date.Year, $Date.Hour ,$Date.Minute, $Date.Second) -join "."
$Report | Export-CSV -NoTypeInformation -Encoding UTF8 $ENV:TEMP\$Name.xlsx
#   Confirmation box
$title = 'Confirm'
$question = 'Do you want to open file in Excel?'
$choices = '&Yes', '&No'
$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
#   Logic for Confirmation box
if ($decision -eq 0) {
    Write-Host "Opening in Excel..."
    Write-Host "The Report is located in $ENV:TEMP\$Name.xlsx"
    Start-Process Excel $ENV:TEMP\$Name.xlsx
}
else {
    Write-Host "The Report is located in $ENV:TEMP\$Name.xlsx"
}