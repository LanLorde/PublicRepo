<#
TO DO:
Convert this to work with Office 365


#>



# Tests required Connection and or Installation of MSOnline Module

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
}
	  
  $Report | Export-CSV -NoTypeInformation -Encoding UTF8 $ENV:TEMP\$Name.csv
  Write-Host "The Report is located in $ENV:TEMP\$Name.csv"