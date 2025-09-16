function Export-IntunePolicies {
    . $PSScriptRoot\Backup\Export-IntunePolicies.ps1
    Export-IntunePolicies @PSBoundParameters
}

function New-AllIntunePolicyDSCConfig {
    . $PSScriptRoot\Utils\New-AllIntunePolicyDSCConfig.ps1
    New-AllIntunePolicyDSCConfig @PSBoundParameters
}

Export-ModuleMember -Function *