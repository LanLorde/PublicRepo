
<#
.SYNOPSIS
Scan a subnet for ARP/Neighbor entries, report current IP conflicts, and optionally maintain JSON history to flag when an IP is later seen with a different MAC (MAC churn).

.DESCRIPTION
Refreshes the neighbor cache by pinging a CIDR range, collects current IP→MAC mappings (canonical string arrays), reports conflicts (multiple MACs per IP), and can update/load a history file to detect churn across runs (NewIP/NewMAC/NoChange).
Zero MACs (00-00-00-00-00-00 / 00:00:00:00:00:00) are excluded by default; use -IncludeZeroMac to keep them.
When no conflicts and no churn are found, the function prints a concise summary and returns without emitting object rows.

.PARAMETER Subnet
IPv4 subnet in CIDR notation (e.g., 192.168.1.0/24).

.PARAMETER InterfaceAlias
Specific interface to query (e.g., "Ethernet"). If omitted, all interfaces are considered.

.PARAMETER SampleCount
Number of pings per IP to refresh the neighbor cache (default: 2).

.PARAMETER TimeoutSeconds
Ping timeout per sample (default: 1 second).

.PARAMETER ClearCache
If set, removes the neighbor entry for the IP between samples (requires elevated session).

.PARAMETER IncludeUnresponsive
Include IPs that didn’t respond to ping but still appear in the neighbor table (single‑MAC rows).

.PARAMETER UpdateHistory
Optional. Load prior JSON history from CachePath, report churn (NewIP/NewMAC/NoChange), then persist updated history.

.PARAMETER CachePath
Path to the JSON history file. Defaults:
$env:LOCALAPPDATA\DuplicateIP\neighbor-history.json

.PARAMETER IncludeZeroMac
Include zero/empty MACs (00-00-00-00-00-00 / 00:00:00:00:00:00). Default is to exclude.

.PARAMETER OnlyConflicts
Only emit rows for current conflicts and churn (NewIP/NewMAC). Suppresses "NoChange" rows.

.OUTPUTS
PSCustomObject with:
- IPAddress
- InterfaceAlias
- CurrentMACs
- PriorMACs
- NewMACs
- ChangeType       (NewIP | NewMAC | NoChange | None)
- ConflictDetected (true if multiple CurrentMACs)
- Notes

.EXAMPLE
Find-DuplicateIP -Subnet 192.168.1.0/24

.EXAMPLE
Find-DuplicateIP -Subnet 10.1.1.0/24 -InterfaceAlias "Ethernet" -SampleCount 3 -TimeoutSeconds 2

.EXAMPLE
Find-DuplicateIP -Subnet 172.16.5.0/24 -UpdateHistory

.EXAMPLE
Find-DuplicateIP -Subnet 192.168.50.0/24 -UpdateHistory -CachePath "C:\Temp\neighbor-history.json" -IncludeZeroMac

.EXAMPLE
Find-DuplicateIP -Subnet 10.1.1.0/24 -OnlyConflicts
#>
function Find-DuplicateIP {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/(?:[8-9]|[1-2]\d|3[0-2])$')]
        [string] $Subnet,

        [Parameter()]
        [string] $InterfaceAlias,

        [Parameter()]
        [ValidateRange(1,10)]
        [int] $SampleCount = 2,

        [Parameter()]
        [ValidateRange(1,5)]
        [int] $TimeoutSeconds = 1,

        [Parameter()]
        [switch] $ClearCache,

        [Parameter()]
        [switch] $IncludeUnresponsive,

        [Parameter()]
        [switch] $UpdateHistory,

        [Parameter()]
        [string] $CachePath = (Join-Path $env:LOCALAPPDATA "DuplicateIP\neighbor-history.json"),

        [Parameter()]
        [switch] $IncludeZeroMac,

        [Parameter()]
        [switch] $OnlyConflicts
    )

    # ----------------- Helpers -----------------

    function ConvertTo-IPsFromCidr {
        param([string] $Cidr)

        $parts    = $Cidr.Split('/')
        $ipStr    = $parts[0]
        $prefix   = [int]$parts[1]
        $hostBits = 32 - $prefix

        $oct   = $ipStr.Split('.') | ForEach-Object { [int]$_ }
        $ipInt = ($oct[0] -shl 24) -bor ($oct[1] -shl 16) -bor ($oct[2] -shl 8) -bor $oct[3]

        # Mask: (2^32 - 1) - (2^hostBits - 1) [safe; no signed overflow]
        $maskInt    = ((1L -shl 32 - 1L) - ((1L -shl $hostBits) - 1L))
        $networkInt = $ipInt -band $maskInt
        $hostCount  = 1 -shl $hostBits

        $list = New-Object System.Collections.Generic.List[string]
        $start = 0
        $end   = $hostCount - 1
        if ($hostCount -ge 4) { $start = 1; $end = $hostCount - 2 } # drop network/broadcast

        for ($i = $start; $i -le $end; $i++) {
            $addrInt = $networkInt + $i
            $o0 = ($addrInt -shr 24) -band 0xFF
            $o1 = ($addrInt -shr 16) -band 0xFF
            $o2 = ($addrInt -shr 8)  -band 0xFF
            $o3 = $addrInt -band 0xFF
            $list.Add("$o0.$o1.$o2.$o3") | Out-Null
        }
        return $list.ToArray()
    }

    function Canonicalize-Mac {
        param([string] $Mac)
        if ([string]::IsNullOrWhiteSpace($Mac)) { return '' }
        $m = $Mac.Trim().ToUpper().Replace(':','-')
        return $m
    }

    function Is-ZeroOrEmptyMac {
        param([string] $Mac)
        if ([string]::IsNullOrWhiteSpace($Mac)) { return $true }
        $m = Canonicalize-Mac $Mac
        return ($m -eq '00-00-00-00-00-00')
    }

    function Filter-MACs {
        param([string[]] $Macs, [switch] $IncludeZeros)
        $safe = @($Macs | ForEach-Object { Canonicalize-Mac $_ })  # canonical string[]
        $list = New-Object System.Collections.Generic.List[string]
        foreach ($m in $safe) {
            if (-not $IncludeZeros -and (Is-ZeroOrEmptyMac $m)) { continue }
            if ([string]::IsNullOrWhiteSpace($m)) { continue }
            if (-not ($list.Contains($m))) { $list.Add($m) | Out-Null }
        }
        return $list.ToArray()
    }

    function Get-NeighborMACsForIPs {
        param(
            [string[]] $IPs,
            [string]   $Iface
        )
        $ipSet = New-Object System.Collections.Generic.HashSet[string]
        foreach ($ip in $IPs) { $null = $ipSet.Add($ip) }

        $getParams = @{
            AddressFamily = 'IPv4'
            ErrorAction   = 'SilentlyContinue'
        }
        if ($Iface) { $getParams['InterfaceAlias'] = $Iface }

        # Build IP -> string[] deterministically
        $map = @{}
        $entries = Get-NetNeighbor @getParams | Where-Object { $ipSet.Contains($_.IPAddress) }
        foreach ($e in $entries) {
            $ip  = [string]$e.IPAddress
            $mac = Canonicalize-Mac $e.LinkLayerAddress
            if (-not $map.ContainsKey($ip)) {
                $map[$ip] = New-Object System.Collections.Generic.List[string]
            }
            if (-not [string]::IsNullOrWhiteSpace($mac)) {
                if (-not ($map[$ip].Contains($mac))) { $map[$ip].Add($mac) | Out-Null }
            }
        }
        foreach ($k in @($map.Keys)) {
            $map[$k] = Filter-MACs -Macs $map[$k].ToArray() -IncludeZeros:$IncludeZeroMac
        }
        return $map
    }

    function Remove-NeighborEntry {
        param(
            [string] $IP,
            [string] $Iface
        )
        try {
            $rmParams = @{
                IPAddress   = $IP
                ErrorAction = 'SilentlyContinue'
                Confirm     = $false
            }
            if ($Iface) { $rmParams['InterfaceAlias'] = $Iface }
            Remove-NetNeighbor @rmParams | Out-Null
        } catch { }
    }

    function Ensure-CachePath {
        param([string] $Path)
        $dir = Split-Path -Path $Path -Parent
        if (-not (Test-Path -Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    }

    function Load-History {
        param([string] $Path)
        if (Test-Path -Path $Path) {
            try { return (Get-Content -Path $Path -Raw | ConvertFrom-Json) }
            catch { return $null }
        }
        return $null
    }

    # Recursively convert PSCustomObject/IDictionary trees into hashtables so ContainsKey/indexing works
    function ConvertTo-HashtableDeep {
        param([object] $Obj)
        if ($Obj -is [hashtable]) { return $Obj }
        if ($Obj -is [System.Collections.IDictionary]) {
            $ht = @{}
            foreach ($k in $Obj.Keys) { $ht[$k] = ConvertTo-HashtableDeep $Obj[$k] }
            return $ht
        }
        if ($Obj -is [psobject]) {
            $ht = @{}
            foreach ($p in $Obj.PSObject.Properties) { $ht[$p.Name] = ConvertTo-HashtableDeep $p.Value }
            return $ht
        }
        if ($Obj -is [System.Collections.IEnumerable] -and ($Obj -isnot [string])) {
            $arr = @()
            foreach ($i in $Obj) { $arr += ,(ConvertTo-HashtableDeep $i) }
            return $arr
        }
        return $Obj
    }

    function Save-History {
        param(
            [hashtable] $CurrentMap, # IP -> string[]
            [psobject]  $History,
            [string]    $Path
        )
        Ensure-CachePath -Path $Path

        if (-not $History) {
            $History = [PSCustomObject]@{
                SchemaVersion  = 1
                Created        = (Get-Date).ToString('o')
                Subnet         = $Subnet
                InterfaceAlias = $InterfaceAlias
                IPs            = @{}
            }
        }

        # Ensure IPs and nested maps are hashtables
        $History.IPs = ConvertTo-HashtableDeep $History.IPs

        foreach ($ip in $CurrentMap.Keys) {
            $macs = Filter-MACs -Macs @($CurrentMap[$ip]) -IncludeZeros:$IncludeZeroMac

            if (-not $History.IPs.ContainsKey($ip)) {
                $History.IPs[$ip] = @{
                    MACs         = $macs
                    FirstSeen    = (Get-Date).ToString('o')
                    LastSeen     = (Get-Date).ToString('o')
                    SeenCount    = 1
                    MACFirstSeen = @{}
                    MACLastSeen  = @{}
                }
                foreach ($m in $macs) {
                    $History.IPs[$ip].MACFirstSeen[$m] = (Get-Date).ToString('o')
                    $History.IPs[$ip].MACLastSeen[$m]  = (Get-Date).ToString('o')
                }
            } else {
                # Ensure nested maps exist and are hashtables
                if ($History.IPs[$ip].MACFirstSeen -isnot [hashtable]) { $History.IPs[$ip].MACFirstSeen = ConvertTo-HashtableDeep $History.IPs[$ip].MACFirstSeen }
                if ($History.IPs[$ip].MACLastSeen  -isnot [hashtable]) { $History.IPs[$ip].MACLastSeen  = ConvertTo-HashtableDeep $History.IPs[$ip].MACLastSeen  }

                $priorMacs = @($History.IPs[$ip].MACs | ForEach-Object { Canonicalize-Mac $_ })
                $union     = New-Object System.Collections.Generic.List[string]
                foreach ($m in $priorMacs) { if (-not ($union.Contains($m))) { $union.Add($m) | Out-Null } }
                foreach ($m in $macs) {
                    if (-not ($union.Contains($m))) {
                        $union.Add($m) | Out-Null
                        $History.IPs[$ip].MACFirstSeen[$m] = (Get-Date).ToString('o')
                    }
                    $History.IPs[$ip].MACLastSeen[$m] = (Get-Date).ToString('o')
                }
                $History.IPs[$ip].MACs      = $union.ToArray()
                $History.IPs[$ip].LastSeen  = (Get-Date).ToString('o')
                $History.IPs[$ip].SeenCount = [int]$History.IPs[$ip].SeenCount + 1
            }
        }

        $json = $History | ConvertTo-Json -Depth 12
        Set-Content -Path $Path -Value $json -Encoding UTF8
        Write-Host "History updated: $Path"
        return $History
    }

    # ----------------- Scan & collect -----------------

    $ips = ConvertTo-IPsFromCidr -Cidr $Subnet

    foreach ($ip in $ips) {
        for ($s = 1; $s -le $SampleCount; $s++) {
            if ($ClearCache) { Remove-NeighborEntry -IP $ip -Iface $InterfaceAlias }
            $pingParams = @{
                TargetName     = $ip
                Count          = 1
                TimeoutSeconds = $TimeoutSeconds
                Quiet          = $true
            }
            try { Test-Connection @pingParams } catch { }
        }
    }

    # Build current neighbor map (IP -> string[])
    $currentMap = Get-NeighborMACsForIPs -IPs $ips -Iface $InterfaceAlias
    if ($currentMap.Keys.Count -eq 0) {
        Write-Host "No neighbors observed in $Subnet. Increase -TimeoutSeconds or -SampleCount, or verify interface selection."
        return
    }

    # ----------------- Prepare output -----------------

    $rows = New-Object System.Collections.Generic.List[psobject]

    # Current conflicts
    foreach ($ip in $currentMap.Keys) {
        $macs = Filter-MACs -Macs @($currentMap[$ip]) -IncludeZeros:$IncludeZeroMac
        $isConflict = ($macs.Count -gt 1)
        if ($isConflict -or $IncludeUnresponsive) {
            if (($OnlyConflicts -and $isConflict) -or (-not $OnlyConflicts)) {
                $rows.Add([PSCustomObject]@{
                    IPAddress        = $ip
                    InterfaceAlias   = $InterfaceAlias
                    CurrentMACs      = $macs
                    PriorMACs        = @()
                    NewMACs          = @()
                    ChangeType       = 'None'
                    ConflictDetected = $isConflict
                    Notes            = if ($isConflict) { 'Current run: multiple MACs for IP' } else { 'Included per settings' }
                }) | Out-Null
            }
        }
    }

    # History: churn detection and persistence (optional)
    $newCount = 0
    $unchangedCount = 0
    if ($UpdateHistory) {
        $history  = Load-History -Path $CachePath

        # Ensure IPs becomes a hashtable for key membership checks (and nested maps too)
        $priorMap = @{} # IP -> string[]
        if ($history -and $history.IPs) {
            $history.IPs = ConvertTo-HashtableDeep $history.IPs
            foreach ($k in $history.IPs.Keys) {
                $macs = $history.IPs[$k].MACs
                $priorMap[$k] = Filter-MACs -Macs @($macs | ForEach-Object { Canonicalize-Mac $_ }) -IncludeZeros:$IncludeZeroMac
            }
        }

        foreach ($ip in $currentMap.Keys) {
            $curr = Filter-MACs -Macs @($currentMap[$ip]) -IncludeZeros:$IncludeZeroMac
            $currConflict = ($curr.Count -gt 1)
            if (-not $priorMap.ContainsKey($ip)) {
                $newCount++
                if (($OnlyConflicts -and $currConflict) -or (-not $OnlyConflicts)) {
                    $rows.Add([PSCustomObject]@{
                        IPAddress        = $ip
                        InterfaceAlias   = $InterfaceAlias
                        CurrentMACs      = $curr
                        PriorMACs        = @()
                        NewMACs          = $curr
                        ChangeType       = 'NewIP'
                        ConflictDetected = $currConflict
                        Notes            = 'IP not present in history'
                    }) | Out-Null
                }
            } else {
                $prior   = $priorMap[$ip]
                $newMacs = New-Object System.Collections.Generic.List[string]
                foreach ($m in $curr) { if (-not ($prior -contains $m)) { $newMacs.Add($m) | Out-Null } }
                if ($newMacs.Count -gt 0) {
                    $newCount++
                    if (($OnlyConflicts -and $currConflict) -or (-not $OnlyConflicts)) {
                        $rows.Add([PSCustomObject]@{
                            IPAddress        = $ip
                            InterfaceAlias   = $InterfaceAlias
                            CurrentMACs      = $curr
                            PriorMACs        = $prior
                            NewMACs          = $newMacs.ToArray()
                            ChangeType       = 'NewMAC'
                            ConflictDetected = $currConflict
                            Notes            = 'New MAC observed for existing IP'
                        }) | Out-Null
                    }
                } else {
                    $unchangedCount++
                    if (-not $OnlyConflicts) {
                        $rows.Add([PSCustomObject]@{
                            IPAddress        = $ip
                            InterfaceAlias   = $InterfaceAlias
                            CurrentMACs      = $curr
                            PriorMACs        = $prior
                            NewMACs          = @()
                            ChangeType       = 'NoChange'
                            ConflictDetected = $currConflict
                            Notes            = 'No MAC churn vs history'
                        }) | Out-Null
                    }
                }
            }
        }

        # Persist updated history (deep-converted to keep hashtables)
        $history = Save-History -CurrentMap $currentMap -History $history -Path $CachePath
    }

    # ----------------- Summaries & Output -----------------

    $out = $rows.ToArray() |
        Sort-Object -Property @{Expression='ChangeType';Descending=$false}, @{Expression='ConflictDetected';Descending=$true}, @{Expression='IPAddress';Descending=$false}

    $currConflictCount = ($out | Where-Object { $_.ChangeType -eq 'None' -and $_.ConflictDetected }).Count
    $histChangeCount   = ($out | Where-Object { $_.ChangeType -in @('NewIP','NewMAC') }).Count

    Write-Host "Summary:"
    Write-Host "  Current Conflicts Found: $currConflictCount"
    if ($UpdateHistory) {
        Write-Host "  Historical Changes: $histChangeCount (New or NewMAC)"
        Write-Host "  Unchanged vs History: $unchangedCount"
        Write-Host "  History File: $CachePath"
    }

    if ($currConflictCount -eq 0 -and (-not $UpdateHistory -or $histChangeCount -eq 0)) {
        Write-Host "No duplicates or changes detected in $Subnet."
        return
    }

    $out
}