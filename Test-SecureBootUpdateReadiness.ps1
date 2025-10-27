function Test-SecureBootUpdateReadiness {
<#
.SYNOPSIS
Audits Windows devices for readiness to receive Microsoft-managed Secure Boot (UEFI) certificate updates.

.DESCRIPTION
Checks Secure Boot enablement, diagnostic data (telemetry) level, the MicrosoftUpdateManagedOptIn registry key,
Windows Update service state, and whether WSUS is configured. Returns a PSObject per device with pass/fail details.

.EXAMPLE
Test-SecureBootUpdateReadiness

Audits the local machine.

.EXAMPLE
'PC01','PC02' | Test-SecureBootUpdateReadiness -Credential (Get-Credential)

Audits multiple remote machines using PowerShell remoting with supplied credentials.
#>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]] $ComputerName = @($env:COMPUTERNAME),

        [Parameter()]
        [pscredential] $Credential
    )
    begin {
        $scriptBlock = {
            $result = [pscustomobject]@{
                ComputerName                    = $env:COMPUTERNAME
                UEFIMode                        = $false
                SecureBootEnabled               = $false
                SecureBootEnabledSource         = $null
                DiagnosticDataLevel             = $null
                DiagnosticDataMeetsRequirement  = $false
                MicrosoftUpdateManagedOptInHex  = $null
                MicrosoftUpdateManagedOptInOk   = $false
                WindowsUpdateServiceState       = $null
                WSUSConfigured                  = $false
                OverallReady                    = $false
                Notes                           = @()
            }

            # Detect Secure Boot status (prefer cmdlet; fall back to registry)
            try {
                $sb = $null
                $sb = Confirm-SecureBootUEFI -ErrorAction Stop
                $result.UEFIMode = $true
                $result.SecureBootEnabled = [bool]$sb
                $result.SecureBootEnabledSource = 'Confirm-SecureBootUEFI'
            } catch {
                # Not UEFI or cmdlet unavailable; try registry
                try {
                    $stateKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State'
                    if (Test-Path $stateKey) {
                        $uefi = (Get-ItemProperty -Path $stateKey -Name UEFISecureBootEnabled -ErrorAction SilentlyContinue).UEFISecureBootEnabled
                        if ($uefi -ne $null) {
                            $result.UEFIMode = $true
                            $result.SecureBootEnabled = [int]$uefi -eq 1
                            $result.SecureBootEnabledSource = 'Registry'
                        }
                    }
                } catch {
                    $result.Notes += 'Unable to read Secure Boot State from registry.'
                }
            }

            # Diagnostic data (telemetry) – policy path preferred
            # Accept values >= 1 (Required/Basic or higher) as meeting Microsoft guidance
            $diagLevel = $null
            $policyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
            $runtimePath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'
            try {
                if (Test-Path $policyPath) {
                    $diagLevel = (Get-ItemProperty -Path $policyPath -Name AllowTelemetry -ErrorAction SilentlyContinue).AllowTelemetry
                }
                if ($diagLevel -eq $null -and (Test-Path $runtimePath)) {
                    $diagLevel = (Get-ItemProperty -Path $runtimePath -Name AllowTelemetry -ErrorAction SilentlyContinue).AllowTelemetry
                }
            } catch {
                $result.Notes += 'Unable to read diagnostic data policy.'
            }
            $result.DiagnosticDataLevel = $diagLevel
            if ($diagLevel -is [int] -and $diagLevel -ge 1) {
                $result.DiagnosticDataMeetsRequirement = $true
            } else {
                $result.Notes += 'Diagnostic data is disabled or below Required (value < 1).'
            }

            # Microsoft-managed Secure Boot updates opt-in (DWORD 0x5944)
            $optInHex = $null
            $optInOk  = $false
            $optKeyCandidates = @(
                'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot',   # common casing
                'HKLM:\SYSTEM\CurrentControlSet\Control\Secureboot'    # casing per some docs; registry is case-insensitive
            )
            foreach ($k in $optKeyCandidates) {
                try {
                    if (Test-Path $k) {
                        $val = (Get-ItemProperty -Path $k -Name MicrosoftUpdateManagedOptIn -ErrorAction SilentlyContinue).MicrosoftUpdateManagedOptIn
                        if ($val -ne $null) {
                            $optInHex = ('0x{0:X}' -f [int]$val)
                            if ([int]$val -eq 0x5944) { $optInOk = $true }
                            break
                        }
                    }
                } catch {
                    $result.Notes += "Unable to read MicrosoftUpdateManagedOptIn at $k."
                }
            }
            $result.MicrosoftUpdateManagedOptInHex = $optInHex
            $result.MicrosoftUpdateManagedOptInOk  = $optInOk
            if (-not $optInOk) {
                $result.Notes += 'MicrosoftUpdateManagedOptIn not set to 0x5944.'
            }

            # Windows Update service and WSUS info (informational)
            try {
                $wusvc = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
                $result.WindowsUpdateServiceState = if ($wusvc) { "$($wusvc.Status) / $($wusvc.StartType)" } else { 'NotFound' }
            } catch {
                $result.Notes += 'Unable to query Windows Update service state.'
            }
            try {
                $wuPolicyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
                $result.WSUSConfigured = (Test-Path $wuPolicyKey) -and `
                    ((Get-ItemProperty -Path $wuPolicyKey -Name WUServer -ErrorAction SilentlyContinue).WUServer)
            } catch {
                $result.Notes += 'Unable to query WSUS policy.'
            }

            # Overall readiness – Microsoft-managed path
            # Requirements: UEFI + Secure Boot ON, DiagnosticData >= 1, OptIn = 0x5944
            $result.OverallReady = $result.UEFIMode -and $result.SecureBootEnabled -and `
                                   $result.DiagnosticDataMeetsRequirement -and $result.MicrosoftUpdateManagedOptInOk

            return $result
        }
    }
    process {
        foreach ($name in $ComputerName) {
            if ($name -in @('localhost', $env:COMPUTERNAME) -or $name -eq '.') {
                & $scriptBlock
            } else {
                $icmParams = @{
                    ComputerName = $name
                    ScriptBlock  = $scriptBlock
                    ErrorAction  = 'Stop'
                }
                if ($PSBoundParameters.ContainsKey('Credential')) {
                    $icmParams.Credential = $Credential
                }
                try {
                    Invoke-Command @icmParams
                } catch {
                    [pscustomobject]@{
                        ComputerName                    = $name
                        UEFIMode                        = $null
                        SecureBootEnabled               = $null
                        SecureBootEnabledSource         = $null
                        DiagnosticDataLevel             = $null
                        DiagnosticDataMeetsRequirement  = $false
                        MicrosoftUpdateManagedOptInHex  = $null
                        MicrosoftUpdateManagedOptInOk   = $false
                        WindowsUpdateServiceState       = $null
                        WSUSConfigured                  = $null
                        OverallReady                    = $false
                        Notes                           = @("Remote query failed: $($_.Exception.Message)")
                    }
                }
            }
        }
    }
}
Test-SecureBootUpdateReadiness