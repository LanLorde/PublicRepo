Function Get-WSUSsettings {
#################Query Information#########################
$DisabledAccess1 = (GP HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate).DisableWindowsUpdateAccess
$UpdateServer = (GP HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate).WUServer
$StatusServer = (GP HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate).WUStatusServer
	
	
$DisabledAccess2 = (GP HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer).NoWindowsUpdate

$DisabledAccess3 = ("GP HKLM:\SYSTEM\Internet Communication Management\Internet Communication").DisableWindowsUpdateAccess

$DA4 = Test-Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\WindowsUpdate
    IF($DA4 = $True){
$DisabledAccess4 = (GP HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\WindowsUpdate).DisableWindowsUpdateAccess
}
$AUoptions = (GP HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU).AUOptions
$AutoUpdates = (GP HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU).NoAutoUpdate
$UseWSUS = (GP HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU).UseWUServer


###################OutPut#######################
#1

    Write-Host Is WSUS Enabled?
    If ($UseWSUS -eq 1)
	{Write-Host YES -BackgroundColor Green}
	Else{Write-Host NO -BackgroundColor Red}
    If ($UpdateServer -ne $null)
    {Write-Host WSUS Server:$UpdateServer}
    Else {$NULL}
    If ($StatusServer -ne $null)
    {Write-Host Status Server:$StatusServer}
    Else {$NULL}

#2
    Write-Host Auto Upates Allowed?
    If ($AutoUpdates -eq 0)
    {Write-Host YES -BackgroundColor Green}
    Else{Write-Host NO -BackgroundColor Red}

    Write-Host Auto Update Options
    If ($AUoptions -eq 2)
    {Write-Host Notify before download}
    Elseif($AUoptions -eq 3)
    {Write-Host Automatically download and notify of installation}
    Elseif ($AUoptions -eq 4)
    {Write-Host Automatically download and schedule installation}
    ElseIf ($AUoptions -eq 5)
    {Write-Host Automatic Updates is required and users can configure it}
    Else{$Null}

#3
    Write-Host Access Disabled?
    If (($DisabledAccess1 -eq 0) -or ($DisabledAccess1 -eq $Null))
	{Write-Host "Not Disabled" -BackgroundColor Green}
		Else {Write-Host Windows Update Blocked}
	
	If (($DisabledAccess2 -eq 0) -or ($DisabledAccess2 -eq $Null))
	{Write-Host "Not Disabled" -BackgroundColor Green}
	Else {Write-Host Windows Update Blocked}

    If (($DisabledAccess3 -eq 0) -or ($DisabledAccess3 -eq $Null))
	{Write-Host "Not Disabled" -BackgroundColor Green}
	Else {Write-Host Windows Update Blocked}

    If (($DisabledAccess4 -eq 0) -or ($DisabledAccess4 -eq $Null))
	{Write-Host "Not Disabled" -BackgroundColor Green}
	Else {Write-Host Windows Update Blocked}



}