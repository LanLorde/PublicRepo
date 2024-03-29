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
	$MsOn = ((Get-MsolCompanyInformation -ErrorAction Stop | Select-Object InitialDomain).InitialDomain) -split "\." -replace "\." | Select-Object -First 1
	Write-Host "You're currently connected to"$MsOn" Office 365 Online Module" -BackgroundColor DarkGreen
  
  }
  Catch {
	Write-Host "You are not connected to any Microsoft Office Online Tenants" -BackgroundColor Red
	Write-Host "Please login to your Office 365 Tenant"
	Connect-MsolService
  }




  $Date = Get-Date
  $Name = ("Report", $Date.Month, $Date.Day, $Date.Year, $Date.Hour ,$Date.Minute, $Date.Second) -join "."
  $Report = [System.Collections.Generic.List[Object]]::new()
  $i=0

  $Groups = Get-MsolGroup
  Foreach ($Group in $Groups) {
	  $Members = Get-MsolGroupMember -GroupObjectId $Group.ObjectID
	 Foreach ($Member in $Members){
		$ReportLine = [PSCustomObject] @{
			User = $Member.DisplayName
			EmailAddress = $Member.EmailAddress
			Group = $Group.DisplayName -join ","
			GroupType = $Group.GroupType
			Description = $Group.Description
		}
	$Report.Add($ReportLine)
	}
	$i++
	Write-Progress -Activity "Gathering O365 Groups.... BEEP BOP BOOP...." -Status "Scaned: $i of $($Groups.Count)" -PercentComplete (($i / $Groups.Count) * 100)
}
	  
$Report | Export-CSV -NoTypeInformation -Encoding UTF8 $ENV:TEMP\$Name.csv
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