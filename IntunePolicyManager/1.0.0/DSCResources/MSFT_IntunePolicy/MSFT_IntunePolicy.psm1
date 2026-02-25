function Get-TargetResource {
    param ([string]$PolicyPath)
    return @{ PolicyPath = $PolicyPath; Ensure = 'Present' }
}
function Test-TargetResource {
    param ([string]$PolicyPath)
    if (-not (Test-Path $PolicyPath)) { return $false }
    $policy = Get-Content $PolicyPath -Raw | ConvertFrom-Json
    $existing = Get-MgDeviceManagementDeviceConfiguration | Where-Object { $_.DisplayName -eq $policy.displayName }
    if (-not $existing) { return $false }
    return ($existing | ConvertTo-Json -Depth 10) -eq ($policy | ConvertTo-Json -Depth 10)
}
function Set-TargetResource {
    param ([string]$PolicyPath)

    $logDir = Join-Path $env:ProgramData 'IntuneDSCLogs'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

    $policy = Get-Content $PolicyPath -Raw | ConvertFrom-Json
    $existing = Get-MgDeviceManagementDeviceConfiguration | Where-Object { $_.DisplayName -eq $policy.displayName }
    $policy.PSObject.Properties.Remove('id')

    if ($existing) {
        $before = $existing | ConvertTo-Json -Depth 10
        $before | Out-File -FilePath (Join-Path $logDir "$($policy.displayName -replace '[^\w\d]', '_')-before.json")

        Update-MgDeviceManagementDeviceConfiguration -DeviceConfigurationId $existing.Id -BodyParameter $policy

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $logFile = Join-Path $logDir 'IntuneDSC_AuditLog.csv'
        [PSCustomObject]@{
            Timestamp    = $timestamp
            ResourceType = 'MSFT_IntunePolicy'
            DisplayName  = $policy.displayName
            Action       = 'Updated'
            Path         = $PolicyPath
        } | Export-Csv -Path $logFile -Append -NoTypeInformation -Encoding UTF8
    }
    else {
        New-MgDeviceManagementDeviceConfiguration -BodyParameter $policy

        $policy | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path $logDir "$($policy.displayName -replace '[^\w\d]', '_')-after.json")

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $logFile = Join-Path $logDir 'IntuneDSC_AuditLog.csv'
        [PSCustomObject]@{
            Timestamp    = $timestamp
            ResourceType = 'MSFT_IntunePolicy'
            DisplayName  = $policy.displayName
            Action       = 'Created'
            Path         = $PolicyPath
        } | Export-Csv -Path $logFile -Append -NoTypeInformation -Encoding UTF8
    }
}
Export-ModuleMember -Function *