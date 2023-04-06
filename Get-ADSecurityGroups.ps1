<#
	.SYNNOPSIS
		Script to retrieve security group members.
	.DESCRIPTION
		This script retrieves security group members and return the group name and user name for each in a nice readable format.
	.AURTHOR
		Brian Klawitter
		Impact Networking


#>

$Date = Get-Date
$Name = ("SecurityGroups", $Date.Hour, $Date.Minute, $Date.Second) -join "."
$groups = Get-ADGroup -Filter * -Properties *
$output = ForEach ($group in $groups) {
	$members = Get-ADGroupMember $group

	ForEach ($member in $members) {
		New-Object PSObject -Property @{
			GroupName = $group.Name
			UserName  = $member.Name
		}
	}
}

Write-Host "Report is in $ENV:TEMP\$Name.csv"



$title = 'Confirm'
$question = 'Do you want to open file in Excel?'
$choices = '&Yes', '&No'

$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
if ($decision -eq 0) {
	Write-Host "Opening in Excel..."
	$Output | Export-Csv $ENV:TEMP\$Name.csv -NoTypeInformation
	Start-Process Excel $ENV:TEMP\$Name.csv
}
else {
	$Output | Export-Csv $ENV:TEMP\$Name.csv -NoTypeInformation
	Write-Host "Report is in $ENV:TEMP\$Name.csv"
}
