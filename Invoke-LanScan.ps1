function Invoke-LanScan {
    <#
    .SYNOPSIS
    PowerShell-only LAN scanner (ping sweep + DNS + MAC + optional TCP ports).

    .DESCRIPTION
    Scans an IPv4 range defined by CIDR (e.g. 192.168.1.0/24) or start-end (e.g. 192.168.1.10-192.168.1.50).
    Returns objects including IP, Online, HostName, DNSName(s), MAC (best-effort), and OpenPorts (optional).

    .PARAMETER Target
    CIDR (x.x.x.x/nn) or start-end (x.x.x.x-x.x.x.x).

    .PARAMETER Ports
    Optional list of TCP ports to test (e.g. 22,80,443,445,3389).

    .PARAMETER TimeoutMs
    TCP connect timeout per port in milliseconds.

    .PARAMETER Ping
    Enable ICMP ping sweep.

    .PARAMETER ResolveDns
    Enable DNS resolution.

    .PARAMETER IncludeMac
    Attempt MAC resolution via Get-NetNeighbor (best effort; depends on ARP/ND cache).

    .PARAMETER ThrottleLimit
    Parallel worker limit in PowerShell 7+.

    .EXAMPLE
    Invoke-LanScan -Target 192.168.1.0/24 -Ports 80,443,445,3389 | Export-Csv .\scan.csv -NoTypeInformation

    .EXAMPLE
    Invoke-LanScan -Target 192.168.1.10-192.168.1.50 -ResolveDns -IncludeMac | Out-GridView
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Target,

        [int[]]$Ports,

        [int]$TimeoutMs = 400,

        [switch]$Ping = $true,

        [switch]$ResolveDns = $true,

        [switch]$IncludeMac = $true,

        [ValidateRange(1,4096)]
        [int]$ThrottleLimit = 256
    )

    function ConvertTo-UInt32 {
        param([Parameter(Mandatory)][System.Net.IPAddress]$Ip)
        $bytes = $Ip.GetAddressBytes()
        [Array]::Reverse($bytes)
        [BitConverter]::ToUInt32($bytes, 0)
    }

    function ConvertFrom-UInt32 {
        param([Parameter(Mandatory)][UInt32]$Value)
        $bytes = [BitConverter]::GetBytes($Value)
        [Array]::Reverse($bytes)
        [System.Net.IPAddress]::new($bytes).ToString()
    }

    function Expand-TargetToIpList {
        param([Parameter(Mandatory)][string]$T)

        if ($T -match '^\s*(\d{1,3}(\.\d{1,3}){3})\s*/\s*(\d{1,2})\s*$') {
            $baseIp = [System.Net.IPAddress]::Parse($matches[1])
            $prefix = [int]$matches[3]
            if ($prefix -lt 0 -or $prefix -gt 32) { throw "Invalid prefix length: $prefix" }

            $base = ConvertTo-UInt32 -Ip $baseIp
            $mask = if ($prefix -eq 0) { [uint32]0 } else { [uint32]([uint64]0xFFFFFFFF -shl (32 - $prefix)) }
            $network = $base -band $mask
            $broadcast = $network -bor ([uint32]0xFFFFFFFF -bxor $mask)

            $list = New-Object System.Collections.Generic.List[string]
            for ($i = $network; $i -le $broadcast; $i++) {
                $list.Add((ConvertFrom-UInt32 -Value $i))
            }
            return $list
        }

        if ($T -match '^\s*(\d{1,3}(\.\d{1,3}){3})\s*-\s*(\d{1,3}(\.\d{1,3}){3})\s*$') {
            $startIp = [System.Net.IPAddress]::Parse($matches[1])
            $endIp   = [System.Net.IPAddress]::Parse($matches[3])

            $start = ConvertTo-UInt32 -Ip $startIp
            $end   = ConvertTo-UInt32 -Ip $endIp
            if ($end -lt $start) { throw "End IP must be >= Start IP" }

            $list = New-Object System.Collections.Generic.List[string]
            for ($i = $start; $i -le $end; $i++) {
                $list.Add((ConvertFrom-UInt32 -Value $i))
            }
            return $list
        }

        throw "Target must be CIDR (x.x.x.x/nn) or range (x.x.x.x-x.x.x.x). Got: $T"
    }

    function Test-TcpPort {
        param(
            [Parameter(Mandatory)][string]$Ip,
            [Parameter(Mandatory)][int]$Port,
            [Parameter(Mandatory)][int]$Timeout
        )

        $client = [System.Net.Sockets.TcpClient]::new()
        try {
            $iar = $client.BeginConnect($Ip, $Port, $null, $null)
            if (-not $iar.AsyncWaitHandle.WaitOne($Timeout, $false)) {
                return $false
            }
            $client.EndConnect($iar) | Out-Null
            return $true
        }
        catch {
            return $false
        }
        finally {
            $client.Close()
            $client.Dispose()
        }
    }

    $ipList = Expand-TargetToIpList -T $Target

    $scanScript = {
        param($ip, $doPing, $doDns, $doMac, $ports, $timeout)

        $online = $null
        if ($doPing) {
            try {
                $online = Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction Stop
            }
            catch {
                $online = $false
            }
        }

        $dnsNames = @()
        $hostName = $null
        if ($doDns) {
            try {
                $res = Resolve-DnsName -Name $ip -ErrorAction Stop
                $ptr = $res | Where-Object { $_.Type -eq 'PTR' } | Select-Object -First 1
                if ($ptr -and $ptr.NameHost) {
                    $hostName = $ptr.NameHost.TrimEnd('.')
                    $dnsNames = @($hostName)
                }
            }
            catch {
                # ignore
            }

            if (-not $hostName) {
                try {
                    $a = Resolve-DnsName -Name $ip -ErrorAction Stop
                    $dnsNames = $a.NameHost
                }
                catch {
                    # ignore
                }
            }
        }

        $mac = $null
        if ($doMac) {
            try {
                $n = Get-NetNeighbor -IPAddress $ip -ErrorAction Stop | Select-Object -First 1
                if ($n -and $n.LinkLayerAddress) {
                    $mac = $n.LinkLayerAddress
                }
            }
            catch {
                # ignore
            }
        }

        $openPorts = @()
        if ($ports -and $ports.Count -gt 0) {
            foreach ($p in $ports) {
                if (Test-TcpPort -Ip $ip -Port $p -Timeout $timeout) {
                    $openPorts += $p
                }
            }
        }

        [pscustomobject]@{
            IP        = $ip
            Online    = $online
            HostName  = $hostName
            DnsNames  = $dnsNames
            Mac       = $mac
            OpenPorts = $openPorts
        }
    }

    $isPs7 = $PSVersionTable.PSVersion.Major -ge 7

    if ($isPs7) {
        $ipList | ForEach-Object -Parallel {
            & $using:scanScript $_ $using:Ping.IsPresent $using:ResolveDns.IsPresent $using:IncludeMac.IsPresent $using:Ports $using:TimeoutMs
        } -ThrottleLimit $ThrottleLimit
    }
    else {
        foreach ($ip in $ipList) {
            & $scanScript $ip $Ping.IsPresent $ResolveDns.IsPresent $IncludeMac.IsPresent $Ports $TimeoutMs
        }
    }
}
