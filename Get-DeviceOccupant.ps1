
function Get-WorkstationUser {
<#
.SYNOPSIS
Quickly identifies who is using or recently used a Windows workstation by correlating OS session info and Outlook/M365 profile data.

.EXAMPLE
Get-WorkstationUser

.EXAMPLE
Get-WorkstationUser -ComputerName WS-023

.EXAMPLE
Get-WorkstationUser -Detailed
#>
    [CmdletBinding()]
    param(
        [string] $ComputerName,
        [switch] $Detailed
    )

    $scriptBlock = {
        param($wantDetailed)

        $out = [pscustomobject]@{
            ComputerName           = $env:COMPUTERNAME
            Timestamp              = Get-Date
            CurrentInteractiveUser = $null
            ActiveSessionUsers     = @()
            LastLoggedOnUserHint   = $null
            LocalProfiles          = @()
            OutlookProfileOwners   = @()
            M365UPNs               = @()
            EvidenceQuality        = 'Unknown'
            Notes                  = @()
        }

        # Current interactive user
        try {
            $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
            $out.CurrentInteractiveUser = $cs.UserName
        } catch { $out.Notes += $_.Exception.Message }

        # Active sessions
        try {
            $quser = quser 2>$null
            if ($quser) {
                $users = @()
                foreach ($line in $quser | Select-Object -Skip 1) {
                    $cols = ($line -replace '\s{2,}', '|').Split('|').ForEach({ $_.Trim() })
                    if ($cols.Count -ge 1 -and $cols[0]) { $users += $cols[0] }
                }
                $out.ActiveSessionUsers = $users | Sort-Object -Unique
            }
        } catch { $out.Notes += $_.Exception.Message }

        # Last logon hint
        try {
            $logonKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI'
            $k = Get-ItemProperty -Path $logonKey -ErrorAction SilentlyContinue
            if ($k) { $out.LastLoggedOnUserHint = $k.LastLoggedOnUser }
        } catch { $out.Notes += $_.Exception.Message }

        # Local profiles and per-user identities
        $profiles = @()
        try {
            $pl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
            Get-ChildItem $pl -ErrorAction Stop | ForEach-Object {
                $sid = $_.PSChildName
                $p = Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue
                if ($p.ProfileImagePath) {
                    $profiles += [pscustomobject]@{
                        SID              = $sid
                        ProfileImagePath = $p.ProfileImagePath
                        LastWriteTime    = $_.LastWriteTime
                    }
                }
            }
            $out.LocalProfiles = $profiles
        } catch { $out.Notes += $_.Exception.Message }

        function Get-HKU {
            param([string] $Sid, [string] $ProfilePath)
            $hku = "HKU:\$Sid"
            if (-not (Test-Path $hku)) {
                $ntuser = Join-Path $ProfilePath 'NTUSER.DAT'
                if (Test-Path $ntuser) {
                    try { reg.exe load "HKU\$Sid" $ntuser | Out-Null } catch { }
                }
            }
            if (Test-Path $hku) { return $hku }
            return $null
        }

        $officeVersions = @('16.0','15.0','14.0')
        foreach ($prof in $profiles) {
            $hku = Get-HKU -Sid $prof.SID -ProfilePath $prof.ProfileImagePath
            if (-not $hku) { continue }

            foreach ($ver in $officeVersions) {
                $profRoot = Join-Path $hku "Software\Microsoft\Office\$ver\Outlook\Profiles"
                if (Test-Path $profRoot) {
                    $out.OutlookProfileOwners += Get-ChildItem $profRoot -ErrorAction SilentlyContinue |
                        Select-Object -ExpandProperty PSChildName
                }

                $identRoot = Join-Path $hku "Software\Microsoft\Office\$ver\Common\Identity\Identities"
                if (Test-Path $identRoot) {
                    $out.M365UPNs += Get-ChildItem $identRoot -ErrorAction SilentlyContinue |
                        ForEach-Object {
                            $props = Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue
                            $props.EmailAddress
                        }
                }
            }

            $crlRoot = Join-Path $hku 'Software\Microsoft\IdentityCRL\StoredIdentities'
            if (Test-Path $crlRoot) {
                $out.M365UPNs += Get-ChildItem $crlRoot -ErrorAction SilentlyContinue |
                    ForEach-Object {
                        $props = Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue
                        $props.EmailAddress
                    }
            }
        }

        $out.OutlookProfileOwners = $out.OutlookProfileOwners | Where-Object { $_ } | Sort-Object -Unique
        $out.M365UPNs            = $out.M365UPNs            | Where-Object { $_ } | Sort-Object -Unique

        $signals = 0
        if ($out.CurrentInteractiveUser) { $signals++ }
        if ($out.ActiveSessionUsers.Count -gt 0) { $signals++ }
        if ($out.OutlookProfileOwners.Count -gt 0) { $signals++ }
        if ($out.M365UPNs.Count -gt 0) { $signals++ }
        if ($out.LastLoggedOnUserHint) { $signals++ }
        $out.EvidenceQuality = switch ($signals) { {$_ -ge 4} {'High'} 3 {'Medium'} 2 {'Low'} default {'Poor'} }

        if ($wantDetailed) { return $out }

        return [pscustomobject]@{
            ComputerName           = $out.ComputerName
            CurrentInteractiveUser = $out.CurrentInteractiveUser
            ActiveSessionUsers     = $out.ActiveSessionUsers
            LastLoggedOnUserHint   = $out.LastLoggedOnUserHint
            OutlookProfileOwners   = $out.OutlookProfileOwners
            M365UPNs               = $out.M365UPNs
            EvidenceQuality        = $out.EvidenceQuality
        }
    }

    if ($ComputerName) {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock -ArgumentList $Detailed.IsPresent
    } else {
        & $scriptBlock $Detailed.IsPresent
    }
}
Get-WorkstationUser