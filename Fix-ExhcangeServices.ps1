Get-Service | Where-Object { $_.DisplayName -like "Microsoft Exchange *" } | Set-Service StartupType Automatic
Get-Service | Where-Object { $_.DisplayName -eq "IIS Admin Service" } | Set-Service StartupType Automatic
Get-Service | Where-Object { $_.DisplayName -eq "Microsoft Filtering Management Service" } | Set-Service StartupType Automatic
Get-Service | Where-Object { $_.DisplayName -eq "World Wide Web Publishing Service" } | Set-Service StartupType Automatic
Get-Service | Where-Object { $_.DisplayName -like "Microsoft Exchange *" } | Start-Service
Get-Service | Where-Object { $_.DisplayName -eq "IIS Admin Service" } | Start-Service
Get-Service | Where-Object { $_.DisplayName -eq "Microsoft Filtering Management Service" } | Start-Service
Get-Service | Where-Object { $_.DisplayName -eq "World Wide Web Publishing Service" } | Start-Service