Import-Module ActiveDirectory

$root = '\\NEW-SRV\Homes'

Get-ADUser -Filter * -Properties SamAccountName | ForEach-Object {
    $user = $_.SamAccountName
    $path = Join-Path $root $user

    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
    }

    $acl = Get-Acl $path

    $acl.SetAccessRuleProtection($true, $false)

    $ruleUser = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $user,
        'FullControl',
        'ContainerInherit,ObjectInherit',
        'None',
        'Allow'
    )

    $ruleAdmins = New-Object System.Security.AccessControl.FileSystemAccessRule(
        'DOMAIN\Admins',
        'FullControl',
        'ContainerInherit,ObjectInherit',
        'None',
        'Allow'
    )

    $acl.SetAccessRule($ruleUser)
    $acl.SetAccessRule($ruleAdmins)

    Set-Acl -Path $path -AclObject $acl
}
