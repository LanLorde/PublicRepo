Import-Module ActiveDirectory
$old = '\\OLD-SRV\Homes'
$new = '\\NEW-SRV\Homes'
Get-ADUser -Filter "homeDirectory -like '*'" -Properties homeDirectory,enabled |
    Where-Object { $_.enabled -and $_.homeDirectory -and $_.homeDirectory.StartsWith($old, [System.StringComparison]::OrdinalIgnoreCase) } |
    ForEach-Object {
        $updated = $_.homeDirectory -replace ([regex]::Escape($old)), $new
        Set-ADUser -Identity $_.DistinguishedName -Replace @{ homeDirectory = $updated } -WhatIf
        [pscustomobject]@{
            SamAccountName = $_.SamAccountName
            OldHomeDir     = $_.homeDirectory
            NewHomeDir     = $updated
        }
    }