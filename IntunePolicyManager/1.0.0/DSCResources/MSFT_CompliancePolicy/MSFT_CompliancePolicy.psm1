function Get-TargetResource {
    param ([string]$PolicyPath)
    return @{
        PolicyPath = $PolicyPath
        Ensure     = 'Present'
    }
}

function Test-TargetResource {
    param ([string]$PolicyPath)

    if (-not (Test-Path $PolicyPath)) { return $false }
    $policy = Get-Content $PolicyPath -Raw | ConvertFrom-Json
    $existing = Get-MgDeviceManagementDeviceCompliancePolicy | Where-Object { $_.DisplayName -eq $policy.displayName }
    if (-not $existing) { return $false }
    return ($existing | ConvertTo-Json -Depth 10) -eq ($policy | ConvertTo-Json -Depth 10)
}

function Set-TargetResource {
    param ([string]$PolicyPath)

    $policy = Get-Content $PolicyPath -Raw | ConvertFrom-Json
    $policy.PSObject.Properties.Remove('id')

    $logDir = Join-Path $env:ProgramData 'IntuneDSCLogs'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

    $existing = Get-MgDeviceManagementDeviceCompliancePolicy | Where-Object { $_.DisplayName -eq $policy.displayName }
    if ($existing) {
        $before = $existing | ConvertTo-Json -Depth 10
        $before | Out-File -FilePath (Join-Path $logDir "$($policy.displayName -replace '[^\w\d]', '_')-before.json")

        Update-MgDeviceManagementDeviceCompliancePolicy -DeviceCompliancePolicyId $existing.Id -BodyParameter $policy

        $logDir = Join-Path $env:ProgramData 'IntuneDSCLogs'
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $logFile = Join-Path $logDir 'IntuneDSC_AuditLog.csv'
        [PSCustomObject]@{
            Timestamp    = $timestamp
            ResourceType = 'MSFT_CompliancePolicy'
            DisplayName  = $policy.displayName
            Action       = 'Updated'
            Path         = $PolicyPath
        } | Export-Csv -Path $logFile -Append -NoTypeInformation -Encoding UTF8
    } else {
        New-MgDeviceManagementDeviceCompliancePolicy -BodyParameter $policy

        $policy | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path $logDir "$($policy.displayName -replace '[^\w\d]', '_')-after.json")

        $logDir = Join-Path $env:ProgramData 'IntuneDSCLogs'
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $logFile = Join-Path $logDir 'IntuneDSC_AuditLog.csv'
        [PSCustomObject]@{
            Timestamp    = $timestamp
            ResourceType = 'MSFT_CompliancePolicy'
            DisplayName  = $policy.displayName
            Action       = 'Created'
            Path         = $PolicyPath
        } | Export-Csv -Path $logFile -Append -NoTypeInformation -Encoding UTF8
    }
}

Export-ModuleMember -Function *