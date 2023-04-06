<#
.SYNOPSIS
  Queries BitLocker volumes, enables BitLock if not ennabled 
.DESCRIPTION
  <Brief description of script>
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Brian Klawitter
  Creation Date:  <Date>
  Purpose/Change: Initial script development
  Company:        Impact Networking
.EXAMPLE
  .\Set-BitLockerSaveKeyAD
#>


$BLV = Get-BitLockerVolume -MountPoint $env:SystemDrive

if ($null -eq $BLV.KeyProtector) {
    Try {
        Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -RecoveryPasswordProtector -ErrorAction Stop
    }
    Catch [System.Runtime.InteropServices.COMException] {
        Write-Host "A compatible Trusted Platform Module (TPM) Security Device cannot be found on this computer."
    }
    Catch {
        Write-Warning "New Execption Below:"
        $Error[0].Exception.GetType().FullName
    }
    
    Enable-Bitlocker -MountPoint $env:SystemDrive -UsedSpaceOnly -SkipHardwareTest -RecoveryPasswordProtector

    $KeyProtector = $BLV.KeyProtector | Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" }

    $KeyProtectorId = $KeyProtector.KeyProtectorId

    Backup-BitLockerKeyProtector -MountPoint $env:SystemDrive -KeyProtectorId $KeyProtectorId
}

else {
    $KeyProtector = $BLV.KeyProtector | Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" }

    $KeyProtectorId = $KeyProtector.KeyProtectorId
    
    Backup-BitLockerKeyProtector -MountPoint $env:SystemDrive -KeyProtectorId $KeyProtectorId
}



<#

Error thrown when trying to backup TPM to AD and NOT THE RECOVERY PASSWORD.
THE RECOVERY PASSWORD SHOULD BE BACKED UP TO AD.

Error:
System.Management.Automation.InvocationInfo

#>