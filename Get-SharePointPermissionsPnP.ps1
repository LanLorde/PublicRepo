#Function to Get Permissions on a particular on List, Folder or List Item  
Function Get-PnPPermissions([Microsoft.SharePoint.Client.SecurableObject]$Object)  
{  
    #Determine the type of the object  
    Switch($Object.TypedObject.ToString())  
    {  
        "Microsoft.SharePoint.Client.ListItem"  
        {  
            If($Object.FileSystemObjectType -eq "Folder")  
            {  
                $ObjectType = "Folder"  
                #Get the URL of the Folder  
                $Folder = Get-PnPProperty -ClientObject $Object -Property Folder  
                $ObjectTitle = $Object.Folder.Name  
                $ObjectURL = $("{0}{1}" -f $Web.Url.Replace($Web.ServerRelativeUrl,''),$Object.Folder.ServerRelativeUrl)  
            }  
            Else #File or List Item  
            {  
                #Get the URL of the Object  
                Get-PnPProperty -ClientObject $Object -Property File, ParentList  
                If($Null -ne $Object.File.Name)  
                {  
                    $ObjectType = "File"  
                    $ObjectTitle = $Object.File.Name  
                    $ObjectURL = $("{0}{1}" -f $Web.Url.Replace($Web.ServerRelativeUrl,''),$Object.File.ServerRelativeUrl)  
                }  
                else  
                {  
                    $ObjectType = "List Item"  
                    $ObjectTitle = $Object["Title"]  
                    #Get the URL of the List Item  
                    $DefaultDisplayFormUrl = Get-PnPProperty -ClientObject $Object.ParentList -Property DefaultDisplayFormUrl                      
                    $ObjectURL = $("{0}{1}?ID={2}" -f $Web.Url.Replace($Web.ServerRelativeUrl,''), $DefaultDisplayFormUrl,$Object.ID)  
                }  
            }  
        }  
        Default  
        {  
            $ObjectType = "List or Library"  
            $ObjectTitle = $Object.Title  
            #Get the URL of the List or Library  
            $RootFolder = Get-PnPProperty -ClientObject $Object -Property RootFolder      
            $ObjectURL = $("{0}{1}" -f $Web.Url.Replace($Web.ServerRelativeUrl,''), $RootFolder.ServerRelativeUrl)  
        }  
    }  
      
    #Get permissions assigned to the object  
    Get-PnPProperty -ClientObject $Object -Property HasUniqueRoleAssignments, RoleAssignments  
    
    #Check if Object has unique permissions  
    $HasUniquePermissions = $Object.HasUniqueRoleAssignments  
        
    #Loop through each permission assigned and extract details  
    $PermissionCollection = [System.Collections.Generic.List[Object]]::new()
    Foreach($RoleAssignment in $Object.RoleAssignments)  
    {  
        #Get the Permission Levels assigned and Member  
        Get-PnPProperty -ClientObject $RoleAssignment -Property RoleDefinitionBindings, Member  
    
        #Get the Principal Type: User, SP Group, AD Group  
        $PermissionType = $RoleAssignment.Member.PrincipalType  
       
        #Get the Permission Levels assigned  
        $PermissionLevels = $RoleAssignment.RoleDefinitionBindings | Select -ExpandProperty Name  
    
        #Remove Limited Access  
        $PermissionLevels = ($PermissionLevels | Where { $_ -ne "Limited Access"}) -join ","  
    
        #Leave Principals with no Permissions  
        If($PermissionLevels.Length -eq 0) {Continue}  
    
        #Get SharePoint group members  
        If($PermissionType -eq "SharePointGroup")  
        {  
            #Get Group Members  
            $GroupMembers = Get-PnPGroupMember -Identity $RoleAssignment.Member.LoginName  
                    
            #Leave Empty Groups  
            If($GroupMembers.count -eq 0){Continue}  
            $GroupUsers = ($GroupMembers | Select -ExpandProperty Title) -join "; "  
    
            #Add the Data to Object  
            $Permissions = New-Object PSObject  
            $Permissions | Add-Member NoteProperty Object($ObjectType)  
            $Permissions | Add-Member NoteProperty Title($ObjectTitle)  
            $Permissions | Add-Member NoteProperty URL($ObjectURL)  
            $Permissions | Add-Member NoteProperty HasUniquePermissions($HasUniquePermissions)  
            $Permissions | Add-Member NoteProperty Users($GroupUsers)  
            $Permissions | Add-Member NoteProperty Type($PermissionType)  
            $Permissions | Add-Member NoteProperty Permissions($PermissionLevels)  
            $Permissions | Add-Member NoteProperty GrantedThrough("SharePoint Group: $($RoleAssignment.Member.LoginName)")  
            $PermissionCollection.Add($Permissions)  
        }  
        Else  
        {  
            #Add the Data to Object  
            $Permissions = New-Object PSObject  
            $Permissions | Add-Member NoteProperty Object($ObjectType)  
            $Permissions | Add-Member NoteProperty Title($ObjectTitle)  
            $Permissions | Add-Member NoteProperty URL($ObjectURL)  
            $Permissions | Add-Member NoteProperty HasUniquePermissions($HasUniquePermissions)  
            $Permissions | Add-Member NoteProperty Users($RoleAssignment.Member.Title)  
            $Permissions | Add-Member NoteProperty Type($PermissionType)  
            $Permissions | Add-Member NoteProperty Permissions($PermissionLevels)  
            $Permissions | Add-Member NoteProperty GrantedThrough("Direct Permissions")  
            $PermissionCollection.Add($Permissions)  
        }  
    }  
    #Export Permissions to CSV File  
    $PermissionCollection | Export-CSV $ReportFile -NoTypeInformation -Encoding utf8 -Append  
}  
      
#Function to get sharepoint online list permissions report  
Function Generate-PnPListPermissionRpt()  
{  
[cmdletbinding()]  
    Param   
    (     
        [Parameter(Mandatory=$false)] [String] $SiteURL,  
        [Parameter(Mandatory=$false)] [String] $ListName,          
        [Parameter(Mandatory=$false)] [String] $ReportFile,  
        [Parameter(Mandatory=$false)] [switch] $ScanItemLevel,  
        [Parameter(Mandatory=$false)] [switch] $IncludeInheritedPermissions  
    )  
    Try {  
        #Function to Get Permissions of All List Items of a given List  
        Function Get-PnPListItemsPermission([Microsoft.SharePoint.Client.List]$List)  
        {  
            Write-host -f Yellow "`t `t Getting Permissions of List Items in the List:"$List.Title  
     
            #Get All Items from List in batches  
            $ListItems = Get-PnPListItem -List $List -PageSize 500  
     
            $ItemCounter = 0  
            #Loop through each List item  
            ForEach($ListItem in $ListItems)  
            {  
                #Get Objects with Unique Permissions or Inherited Permissions based on 'IncludeInheritedPermissions' switch  
                If($IncludeInheritedPermissions)  
                {  
                    Get-PnPPermissions -Object $ListItem  
                }  
                Else  
                {  
                    #Check if List Item has unique permissions  
                    $HasUniquePermissions = Get-PnPProperty -ClientObject $ListItem -Property HasUniqueRoleAssignments  
                    If($HasUniquePermissions -eq $True)  
                    {  
                        #Call the function to generate Permission report  
                        Get-PnPPermissions -Object $ListItem  
                    }  
                }  
                $ItemCounter++  
                Write-Progress -PercentComplete ($ItemCounter / ($List.ItemCount) * 100) -Activity "Processing Items $ItemCounter of $($List.ItemCount)" -Status "Searching Unique Permissions in List Items of '$($List.Title)'"  
            }  
        }  
   
            #Get the List  
            $List = Get-PnpList -Identity $ListName -Includes RoleAssignments  
               
            Write-host -f Yellow "Getting Permissions of the List '$ListName'..."  
            #Get List Permissions  
            Get-PnPPermissions -Object $List  
   
            #Get Item Level Permissions if 'ScanItemLevel' switch present  
            If($ScanItemLevel)  
            {  
                #Get List Items Permissions  
                Get-PnPListItemsPermission -List $List  
            }  
        Write-host -f Green "`t List Permission Report Generated Successfully!"   
     }  
    Catch {  
        write-host -f Red "Error Generating List Permission Report!" $_.Exception.Message  
   }  
}  


$Date = Get-Date
$Name = ($Date.Month, $Date.Day, $Date.Year, $Date.Hour ,$Date.Minute, $Date.Second) -join "."

#region ***Parameters***
$SiteName = "ssw"  
$SiteURL="https://christopherhouseorg.sharepoint.com/$SiteName/"  
$ListName = "SSW Document Library"
$ReportFile= "$ENV:TEMP\$SiteName-PermissionRpt-$Name.csv" 
#endregion  
   
#Remove the Output report if exists  
#If (Test-Path $ReportFile) { Remove-Item $ReportFile }  
   
#Connect to the Site  
Connect-PnPOnline -URL $SiteURL -Interactive
   
#Get the Web  
$Web = Get-PnPWeb  


Generate-PnPListPermissionRpt -SiteURL $SiteURL -ListName $ListName -ReportFile $ReportFile -ScanItemLevel -IncludeInheritedPermissions