@{
    RootModule = 'IntunePolicyManager.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a17d4ea1-354d-4e91-a77c-5e1c6f7f3a42'
    Author = 'ChatGPT'
    Description = 'Unified module for managing Intune and Conditional Access policies using PowerShell DSC and Graph API.'
    PowerShellVersion = '5.1'
    FunctionsToExport = '*'
    DscResourcesToExport = @('MSFT_IntunePolicy', 'MSFT_ConditionalAccessPolicy', 'MSFT_CompliancePolicy', 'MSFT_DeviceManagementScript')
}