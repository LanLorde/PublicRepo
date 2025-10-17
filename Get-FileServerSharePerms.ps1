<#
.SYNOPSIS
  <Overview of script>
.DESCRIPTION
  This is indended to be ran directly from a file server. It will NOT reach out to the network or get any shares not hosted on the machine running the script.
.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>
.INPUTS
  <Inputs if any, otherwise state None>
  None
.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
  None
.NOTES
  Version:        1.3
  Author:         Brian Klawitter
  Creation Date:  6/22/25
  Purpose/Change: Initial script development
  
  NEED TO MAKE A FUNCTION with advanced paramenters. 
  WHEN THIS IS DONE, PELASE ADD RECURSIVE LOOKUP WITH A PARAMETER FOR "DEPTH" 
#>

$Report = [System.Collections.Generic.List[Object]]::new() 


  # List all SMB Shares
  $shares = Get-SmbShare | Where-Object {$_.Name -notlike "*$"}
  # Get NTFS Permissions
  $FolderCount=0
  foreach ($share in $shares) {
    $Folders = Get-ChildItem $share.Path -Directory -Recurse -Depth 2
    Foreach ($Folder in $Folders){  
    $acl = Get-ACL $Folder.FullName 
      foreach ($access in $acl.Access) {
          $ReportLine = [PSCustomObject]@{
              'Computer'  = $env:COMPUTERNAME
              'Folder'    = $Folder
              'FolderPath'= $Folder.FullName 
              'SharePath' = $share.Name
              'Path'      = $share.Path
              'Identity'  = $access.IdentityReference
              'Access'    = $access.FileSystemRights
              'Type'      = $access.AccessControlType
          }
          $Report.Add($ReportLine)
      }
  $FolderCount++
  }
  Write-Progress -PercentComplete (($FolderCount / $folders.Count) * 100) -Status "Processing $Folder on FileServer" -Activity "$folder processed"
}

  


#   Output Configuration

#   Generate File Name Data
$Date = Get-Date
$Name = ("ShareAccess", $Date.Month, $Date.Day, $Date.Year, $Date.Hour , $Date.Minute, $Date.Second) -join "."

#   Save report to .CSV file
$Report | Export-CSV -NoTypeInformation $ENV:TEMP\$Name.csv
Write-Host "The Report is located in $ENV:TEMP\$Name.csv"

#   Optinal Open In Excel With Confirmation box
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