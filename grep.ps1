filter grep ([string]$Pattern) {
    if ((Out-String -InputObject $_) -match $Pattern) { $_ }
}