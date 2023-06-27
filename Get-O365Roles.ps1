$Date = Get-Date
$Name = ("Report", $Date.Month, $Date.Day, $Date.Year, $Date.Hour ,$Date.Minute, $Date.Second) -join "."
$Report = [System.Collections.Generic.List[Object]]::new()

$Roles = Get-MsolRole
Foreach ($Role in $Roles) {
    $Perms = Get-MsolRoleMember -RoleObjectId $Role.ObjectId
   
    $ReportLine = [PSCustomObject] @{
       Role =  $Role.Name
       DisplayName = $Perms.DisplayName -join ","
       EmailAddress = $Perms.EmailAddress -join ","
    }
$Report.Add($ReportLine)
}
$Report | Export-CSV -NoTypeInformation -Encoding UTF8 $ENV:TEMP\$Name.csv
Write-Host "The Report is located in $ENV:TEMP\$Name.csv"