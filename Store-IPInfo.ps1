<#
$title    = 'Confirm'
$question = 'Do you want to continue?'
$choices  = '&Yes', '&No'

$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
if ($decision -eq 0) {
    Write-Host 'Your choice is Yes.'
} else {
    Write-Host 'Your choice is No.'
}
#>

# Creates and initializes empty data array
[Collections.Generic.List[PSCustomObject]]$Data = @()

# Configure Advanced Function

# Gets IP network configuration
$NICs = gip

ForEach ($NIC in $NICs) {


$IP = [PSCustomObject]@{
Name = $NIC.InterfaceAlias
DNS = $NIC.DNSServer.ServerAddresses -Join ","
IP = $NIC.IPv4Address.IPAddress
Prefix = $NIC.IPv4Address.PrefixLength
Gateway = $NIC.IPv4DefaultGateway.NextHop
}


$Data.Add($IP) | Out-Null

}
Write-Host "Exporting .XML file to C:\NICs.XML"
$Data | Export-Clixml C:\NICs.xml



# To Import Run
<#

$nic = Import-Clixml C:\NICs.xml
$If = (Get-NetAdapter).IfIndex 

New-NetIPAddress -IPAddress $nic.IP -InterfaceIndex $If -DefaultGateway $nic.Gateway -PrefixLength $nic.Prefix;Set-DnsClientServerAddress -InterfaceIndex $if -ServerAddresses $NIC.DNS

#>



