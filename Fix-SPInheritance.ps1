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



$siteURL = "https://christopherhouseorg.sharepoint.com/ea/"

Connect-PnPOnline -Url $siteURL -Interactive

$listName = "External Affairs Library"
$list = Get-PnPList -Identity $listName
$folders = Get-PnPListItem -List $list -PageSize 500 | Where-Object {$_.FileSystemObjectType -eq "Folder"} # -Includes ListItemAllFields.HasUniqueRoleAssignments, ListItemAllFields.ParentList, ListItemAllFields.ID	
Write-Host "Total Folders found" $folders.Count

Foreach ($folder in $folders) {
    $HasUniquePermissions = Get-PnPProperty -ClientObject $folder -Property "HasUniqueRoleAssignments"

    If ($HasUniquePermissions) {
        
        Write-Host "Resetting Permissions on" $Folder.FieldValues.FileRef
        Set-PnPListItemPermission -List $list -Identity $folder -InheritPermissions

    }
}