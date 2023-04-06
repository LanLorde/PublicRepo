<#
	.SYNNOPSIS
		Script to retrieve licensed users with disbaled services.
	.DESCRIPTION
		This script retrieves all licensed users and saves them to a varrible. Then loops though this variable and splats the resluts into a hashtable.
        Then it will loop though those results and parse togeather the data into a final hash table.
        Output variable is there so it can be piped to a csv if the script runner wishes.
	.AURTHOR
		Brian Klawitter
		Impact Networking
    .DATE
        12/15/2021
    .VERSION 
        1.0


#>
#$Report = [System.Collections.Generic.List[Object]]::new()
$Date = Get-Date
$Company = (Get-MsolDomain | Select-Object -Last 1).Name
$Name = ($Company, $Date.Hour, $Date.Minute, $Date.Second) -join "."
$users = Get-MsolUser -All | Where-Object { $_.isLicensed -eq "True" }
$i=0

$output = Foreach ($user in $users) {
    $Lics = $user.Licenses.ServiceStatus
    
    Foreach ($Lic in $Lics) {
        New-Object PSObject -Property @{
            User               = $user.UserPrincipalName
            ServicePlan        = $lic.ServicePlan.ServiceType
            ProvisioningStatus = $lic.ProvisioningStatus
        }
    }
    $i++
    Write-Progress -Activity "Scanning.... BEEP BOP BOOP...." -Status "Scaned: $i of $($users.Count)" -PercentComplete (($i / $users.Count) * 100)

}
Write-Host "Report is in $ENV:TEMP\MFAUsers.csv"
Write-Host "Opening in Excel..."
$output | Export-Csv $ENV:TEMP\$Name.csv -NoTypeInformation
Start-Process Excel $ENV:TEMP\$Name.csv