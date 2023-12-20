<#
.SYNOPSIS
  <Overview of script>
.DESCRIPTION
  <Brief description of script>
.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>
.INPUTS
  <Inputs if any, otherwise state None>
  None
.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
  None
.NOTES
  Version:        1.0
  Author:         Brian Klawitter
  Creation Date:  <Date>
  Purpose/Change: Initial script development
  Company:        Impact Networking
  
.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>


Try {
    $AzOn = (Get-AzureADDomain -ErrorAction Stop).Name | Select-Object -First 1
    Write-Host "You're currently connected to"$AzOn" Azure Online Module" -BackgroundColor DarkGreen

}
Catch {
    Write-Host "You are not connected to any Auzre Online Tenants" -BackgroundColor Red
    Write-Host "Please login to your AzureAD Tenant"
    Connect-AzureAD

}


$Report = [System.Collections.Generic.List[Object]]::new()

$Roles = Get-AzureADdirectoryRole
Foreach ($Role in $Roles) {
    $Perms = Get-AzureADdirectoryRoleMember -Object $Role.ObjectId
   
    $ReportLine = [PSCustomObject] @{
       Role =  $Role.DisplayName
       User = $Perms.DisplayName -join ","
       
    }
$Report.Add($ReportLine)
}
$Report | Export-CSV -NoTypeInformation -Encoding UTF8 $ENV:TEMP\$Name.csv


$Date = Get-Date
$Name = ("AzureAD-Roles-Report", $AzOn, $Date.Month, $Date.Day, $Date.Year, $Date.Hour ,$Date.Minute, $Date.Second) -join "."
Write-Host "The Report is located in $ENV:TEMP\$Name.csv"
#   Confirmation box
$title = 'Confirm'
$question = 'Do you want to open file in Excel?'
$choices = '&Yes', '&No'
$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
#   Logic for Confirmation box
if ($decision -eq 0) {
    Write-Host "Opening in Excel..."
    Start-Process Excel $ENV:TEMP\$Name.csv
}
else {
    Write-Host "The Report is located in $ENV:TEMP\$Name.csv"
}