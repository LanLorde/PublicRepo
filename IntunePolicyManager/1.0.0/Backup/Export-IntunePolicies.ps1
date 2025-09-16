function Export-IntunePolicies {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )

    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    # Export Configuration Profiles
    $deviceConfigs = Get-MgDeviceManagementDeviceConfiguration
    foreach ($config in $deviceConfigs) {
        $details = Get-MgDeviceManagementDeviceConfiguration -DeviceConfigurationId $config.Id
        $file = Join-Path -Path $OutputPath -ChildPath ($details.DisplayName -replace '[^\w\d]', '_') + '.json'
        $details | ConvertTo-Json -Depth 10 | Set-Content -Path $file
    }

    # Export Conditional Access Policies
    $caPolicies = Get-MgConditionalAccessPolicy
    $caPath = Join-Path $OutputPath 'ConditionalAccess'
    if (-not (Test-Path $caPath)) {
        New-Item -Path $caPath -ItemType Directory | Out-Null
    }

    foreach ($ca in $caPolicies) {
        $caDetails = Get-MgConditionalAccessPolicy -ConditionalAccessPolicyId $ca.Id
        $file = Join-Path -Path $caPath -ChildPath ($caDetails.DisplayName -replace '[^\w\d]', '_') + '.json'
        $caDetails | ConvertTo-Json -Depth 10 | Set-Content -Path $file
    }

    Write-Host "Export complete to $OutputPath"
}