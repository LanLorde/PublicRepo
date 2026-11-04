#requires -Version 5.1
# Dependency-free regression suite. All remote queries are mocked; no machines reboot.
[CmdletBinding()]
param([switch]$SkipLiveCheck)
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Get-RebootHistory.ps1')
$script:Passed = 0
function Assert-Equal($Expected, $Actual, [string]$Message) {
    if ($Expected -cne $Actual) { throw ('{0}: expected [{1}], got [{2}]' -f $Message, $Expected, $Actual) }
}
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Test-Case([string]$Name, [scriptblock]$Body) {
    & $Body
    $script:Passed++
    Write-Output ('PASS: ' + $Name)
}
function New-Event {
    param([int]$Id, [datetime]$When, [long]$Record, [hashtable]$Data = @{}, [string]$Provider)
    if (-not $Provider) {
        $Provider = switch ($Id) {
            { $_ -in 12,13 } { 'Microsoft-Windows-Kernel-General' }
            { $_ -in 6005,6006,6008,6009 } { 'EventLog' }
            1074 { 'User32' }
            41 { 'Microsoft-Windows-Kernel-Power' }
            1001 { 'Microsoft-Windows-WER-SystemErrorReporting' }
        }
    }
    $items = foreach ($key in $Data.Keys) {
        if ($key -like 'unnamed*') { '<Data>' + [Security.SecurityElement]::Escape([string]$Data[$key]) + '</Data>' }
        else { '<Data Name="' + $key + '">' + [Security.SecurityElement]::Escape([string]$Data[$key]) + '</Data>' }
    }
    $xml = '<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event"><EventData>' + ($items -join '') + '</EventData></Event>'
    $obj = [pscustomobject]@{ Id=$Id;TimeCreated=$When;RecordId=$Record;ProviderName=$Provider;Xml=$xml }
    $obj | Add-Member -MemberType ScriptMethod -Name ToXml -Value { $this.Xml }
    return $obj
}

# A real local read exercises the Windows query syntax before the mock is installed.
if (-not $SkipLiveCheck) {
    Test-Case 'Native System-log query succeeds' {
        $result = Get-RebootHistory localhost
        Assert-True ($result.Status -in 'Success','Partial','NoEvents') 'Native event query failed.'
        Assert-True ($result.BootHistory -is [array]) 'BootHistory is not an array.'
        Assert-True ($result.UnexpectedShutdowns -is [array]) 'UnexpectedShutdowns is not an array.'
    }
}
$script:Fixtures = @{}
$script:Requests = [Collections.Generic.List[object]]::new()
function Get-WinEvent {
    [CmdletBinding()]
    param([xml]$FilterXml, [string]$ComputerName, [pscredential]$Credential)
    $key = if ($ComputerName) { $ComputerName } else { 'LOCAL' }
    $script:Requests.Add([pscustomobject]@{
        Computer=$ComputerName;HasCredential=$PSBoundParameters.ContainsKey('Credential');Query=$FilterXml.OuterXml
    })
    $value = $script:Fixtures[$key]
    if ($value -eq 'FAIL') { throw 'RPC server unavailable (fixture).' }
    if ($value -eq 'EMPTY_ERROR') {
        $errorRecord = [Management.Automation.ErrorRecord]::new(
            [Exception]::new('No matching events.'), 'NoMatchingEventsFound',
            [Management.Automation.ErrorCategory]::ObjectNotFound, $null)
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
    return $value
}
$end = [datetime]::Parse('2026-11-04T18:00:00Z').ToUniversalTime()
$t = $end.AddDays(-1)
$plan = @{param1='C:\Windows\System32\shutdown.exe';param3='Maintenance';param4='0x80020004';param5='restart';param6='Patch window';param7='TEST\operator'}

Test-Case 'Multiple target arrays are isolated' {
    $script:Fixtures.A = @((New-Event 12 $t 1),(New-Event 1074 $t.AddHours(1) 2 $plan))
    $script:Fixtures.B = @((New-Event 12 $t 3),(New-Event 12 $t.AddHours(2) 4),(New-Event 41 $t.AddHours(2).AddSeconds(2) 5))
    $r = @(Get-RebootHistory A,B -EndTime $end)
    Assert-Equal 2 $r.Count 'Target count'
    Assert-Equal 1 $r[0].BootCount 'A boot count'
    Assert-Equal 2 $r[1].BootCount 'B boot count'
    Assert-Equal 0 $r[0].UnexpectedCount 'A unexpected count'
    Assert-Equal 1 $r[1].UnexpectedCount 'B unexpected count'
    Assert-Equal $null $r[1].LastShutdown 'B inherited A shutdown details'
}
Test-Case 'Pipeline targets are isolated' {
    $r = @('A','B' | Get-RebootHistory -EndTime $end)
    Assert-Equal 2 $r.Count 'Pipeline result count'
    Assert-Equal 1 $r[0].BootCount 'Pipeline A count'
    Assert-Equal 2 $r[1].BootCount 'Pipeline B count'
}
Test-Case 'Computer property binds through the pipeline' {
    $r = [pscustomobject]@{Computer='A'} | Get-RebootHistory -EndTime $end
    Assert-Equal 'A' $r.Computer 'Computer alias'
}
Test-Case 'Missing 1074 still returns history' {
    $r = Get-RebootHistory B -EndTime $end
    Assert-Equal 'Success' $r.Status 'Status'
    Assert-Equal $null $r.LastShutdown 'Absent request'
    Assert-Equal 1 $r.UnexpectedCount 'Unexpected count'
}
Test-Case 'Five percent does not pass a thirty percent filter' {
    $events = for ($i=0; $i -lt 20; $i++) { New-Event 12 $t.AddMinutes(10*$i) (100+$i*2) }
    $script:Fixtures.Percent = @($events) + @((New-Event 41 $t.AddSeconds(1) 101))
    $r = Get-RebootHistory Percent -EndTime $end
    Assert-Equal 5.0 $r.PercentDirty 'Numeric percentage'
    Assert-Equal '5%' $r.PercentDirtyDisplay 'Display percentage'
    Assert-True (-not ($r.PercentDirty -ge 30)) '5 percent incorrectly passes 30 threshold.'
}
Test-Case 'Dates retain UTC precision and native types' {
    $when = $t.AddTicks(1234567)
    $script:Fixtures.Dates = @((New-Event 12 $when 10),(New-Event 1074 $when.AddSeconds(5) 11 $plan))
    $r = Get-RebootHistory Dates -EndTime $end
    Assert-True ($r.LastShutdown -is [datetime]) 'LastShutdown is not a DateTime.'
    Assert-Equal ([DateTimeKind]::Utc) $r.LastShutdown.Kind 'Date kind'
    Assert-Equal $when.Ticks $r.BootHistory[0].Ticks 'Lost date precision'
}
Test-Case 'Latest request is explicitly sorted and named data survives' {
    $script:Fixtures.Sort = @((New-Event 1074 $t 10 $plan),(New-Event 1074 $t.AddHours(1) 20 ($plan + @{extra='x'})))
    $r = Get-RebootHistory Sort -EndTime $end
    Assert-Equal $t.AddHours(1) $r.LastShutdown 'Latest request'
    Assert-Equal 'TEST\operator' $r.LastShutdownUser 'Initiating user'
    Assert-Equal 'C:\Windows\System32\shutdown.exe' $r.LastShutdownProcess 'Initiating process'
    Assert-Equal 'restart' $r.LastShutdownType 'Shutdown type'
}
Test-Case 'Zero boot markers does not divide by zero' {
    $r = Get-RebootHistory Sort -EndTime $end
    Assert-Equal 0 $r.BootCount 'Boot count'
    Assert-Equal $null $r.PercentDirty 'Undefined percentage'
    Assert-True ($null -ne $r.LastShutdown) 'Request was lost.'
}
Test-Case '12 and 6009 describe one boot; service starts are not extra boots' {
    $script:Fixtures.Pair = @((New-Event 12 $t 1),(New-Event 6009 $t.AddSeconds(35) 4),(New-Event 6005 $t.AddSeconds(40) 5))
    $r = Get-RebootHistory Pair -EndTime $end
    Assert-Equal 1 $r.BootCount 'Duplicate startup markers'
}
Test-Case 'Rapid legacy startups remain separate without event 12' {
    $script:Fixtures.Legacy = @((New-Event 6009 $t 1),(New-Event 6009 $t.AddMinutes(1) 2))
    $r = Get-RebootHistory Legacy -EndTime $end
    Assert-Equal 2 $r.BootCount 'Distinct 6009 records were collapsed'
}
Test-Case '41, 6008 and bugcheck correlate to one incident' {
    $script:Fixtures.Crash = @((New-Event 12 $t 1),(New-Event 41 $t.AddSeconds(1) 2 @{BugcheckCode='159'}),(New-Event 6008 $t.AddSeconds(35) 3),(New-Event 1001 $t.AddSeconds(45) 4 @{param1='0x0000009f'}))
    $r = Get-RebootHistory Crash -EndTime $end
    Assert-Equal 1 $r.UnexpectedCount 'One crash counted more than once'
    $detail = @(Get-RebootHistory Crash -EndTime $end -Detailed)
    Assert-Equal 1 @($detail | Where-Object IncidentId | Select-Object -ExpandProperty IncidentId -Unique).Count 'Incident IDs differ'
    Assert-Equal '0x0000009f' @($detail | Where-Object EventId -eq 1001)[0].BugcheckCode 'Bugcheck code'
}
Test-Case 'Two rapid crashes with startup markers stay separate' {
    $script:Fixtures.Rapid = @((New-Event 12 $t 1),(New-Event 41 $t.AddSeconds(1) 2),(New-Event 6008 $t.AddSeconds(20) 3),(New-Event 12 $t.AddSeconds(30) 4),(New-Event 41 $t.AddSeconds(31) 5),(New-Event 6008 $t.AddSeconds(50) 6))
    $r = Get-RebootHistory Rapid -EndTime $end
    Assert-Equal 2 $r.BootCount 'Boot count'
    Assert-Equal 2 $r.UnexpectedCount 'Rapid incidents collapsed'
}
Test-Case 'Two 6008 events without markers stay separate' {
    $script:Fixtures.NoBoot = @((New-Event 6008 $t 10),(New-Event 6008 $t.AddMinutes(1) 11))
    $r = Get-RebootHistory NoBoot -EndTime $end
    Assert-Equal 2 $r.UnexpectedCount 'Unanchored crashes collapsed'
    Assert-Equal 'Partial' $r.Status 'Missing markers should be visible'
}
Test-Case 'Wrong providers cannot impersonate restart events' {
    $script:Fixtures.Wrong = @((New-Event 12 $t 1 @{} 'OtherProvider'),(New-Event 1074 $t 2 $plan 'OtherProvider'))
    $r = Get-RebootHistory Wrong -EndTime $end
    Assert-Equal 'NoEvents' $r.Status 'Wrong-provider rows accepted'
}
Test-Case 'Empty retained history has an explicit result' {
    $script:Fixtures.Empty = @()
    $r = Get-RebootHistory Empty -EndTime $end
    Assert-Equal 'NoEvents' $r.Status 'Empty status'
    Assert-Equal 0 $r.BootCount 'Empty count'
    Assert-Equal $null $r.PercentDirty 'Empty percentage'
}
Test-Case 'Native no-matching-events error is not a connection failure' {
    $script:Fixtures.Empty = 'EMPTY_ERROR'
    Assert-Equal 'NoEvents' (Get-RebootHistory Empty -EndTime $end).Status 'No match error classified incorrectly'
}
Test-Case 'One unreachable target does not suppress the next target' {
    $script:Fixtures.Bad = 'FAIL'
    $r = @(Get-RebootHistory Bad,A -EndTime $end -WarningAction SilentlyContinue)
    Assert-Equal 2 $r.Count 'Failed target was dropped'
    Assert-Equal 'Error' $r[0].Status 'Error status'
    Assert-Equal $null $r[0].BootCount 'Failure presented as healthy zero'
    Assert-Equal 'Success' $r[1].Status 'Following target failed'
}
Test-Case 'Credentials are omitted for every local alias and restored for remote targets' {
    $cred = [pscredential]::new('TEST\operator', (ConvertTo-SecureString 'fixture-only' -AsPlainText -Force))
    $script:Fixtures.LOCAL = @()
    $script:Requests.Clear()
    $null = Get-RebootHistory A,'.','localhost','127.0.0.1','::1',$env:COMPUTERNAME,B -Credential $cred -EndTime $end
    Assert-True $script:Requests[0].HasCredential 'Remote credential missing'
    foreach ($r in @($script:Requests | Select-Object -Skip 1 -First 5)) { Assert-True (-not $r.HasCredential) 'Local credential leaked into query' }
    Assert-True $script:Requests[6].HasCredential 'Credential not restored after local targets'
}
Test-Case 'StartTime and EndTime bound the query and results' {
    $script:Fixtures.Window = @((New-Event 12 $t.AddDays(-2) 1),(New-Event 12 $t 2),(New-Event 12 $end.AddHours(1) 3))
    $r = Get-RebootHistory Window -StartTime $t -EndTime $end
    Assert-Equal 1 $r.BootCount 'Date window'
    Assert-True ($script:Requests[-1].Query -match 'TimeCreated') 'Query did not filter times'
    Assert-True ($script:Requests[-1].Query -match 'Path="System"') 'Query did not select System log'
}
Test-Case 'Recent counts include the exact cutoff and exclude older observations' {
    $script:Fixtures.Recent = @((New-Event 12 $end.AddDays(-30).AddTicks(-1) 1),(New-Event 12 $end.AddDays(-30) 2),(New-Event 12 $end.AddDays(-29) 3))
    $r = Get-RebootHistory Recent -EndTime $end
    Assert-Equal 2 $r.RecentShutdowns 'Thirty-day cutoff'
    Assert-Equal 3 $r.BootCount 'Historical records were lost'
}
Test-Case 'Invalid date range is rejected before querying' {
    $threw = $false
    try { $null = Get-RebootHistory A -StartTime $end.AddDays(1) -EndTime $end } catch { $threw=$true }
    Assert-True $threw 'Invalid range accepted'
}
Test-Case 'Localized 6008 text remains readable without guessed dates' {
    $e = New-Event 6008 $t 1
    $e.Xml = '<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event"><EventData><Data>23:15:00</Data><Data>31/10/2026</Data></EventData></Event>'
    $script:Fixtures.Locale = @($e)
    $r = Get-RebootHistory Locale -EndTime $end -Detailed
    Assert-Equal '31/10/2026 23:15:00' $r.ReportedShutdownTime 'Localized occurrence text'
    Assert-Equal $t $r.TimeCreated 'Detection timestamp'
}
Test-Case 'Malformed event payload produces partial data and a warning' {
    $e = New-Event 1074 $t 1 $plan
    $e.Xml = '<broken'
    $script:Fixtures.Malformed = @($e)
    $r = Get-RebootHistory Malformed -EndTime $end
    Assert-Equal 'Partial' $r.Status 'Malformed payload status'
    Assert-True ($r.HistoryWarnings.Count -gt 0) 'Missing payload warning'
    $detail = Get-RebootHistory Malformed -EndTime $end -Detailed -WarningAction SilentlyContinue
    Assert-Equal 'Partial' $detail.Status 'Malformed timeline row status'
    Assert-True (-not [string]::IsNullOrEmpty($detail.Error)) 'Missing timeline payload error'
}
Test-Case 'RecentDays can be changed independently of the retained-history window' {
    $script:Fixtures.Custom = @((New-Event 12 $end.AddDays(-8) 1),(New-Event 12 $end.AddDays(-6) 2))
    $r = Get-RebootHistory Custom -EndTime $end -RecentDays 7
    Assert-Equal 2 $r.BootCount 'Historical boot count'
    Assert-Equal 1 $r.RecentShutdowns 'Seven-day count'
}
Test-Case 'Detailed no-data and error rows are CSV-friendly' {
    $script:Fixtures.Empty = @()
    $r = @(Get-RebootHistory Empty,Bad -EndTime $end -Detailed -WarningAction SilentlyContinue)
    Assert-Equal 2 $r.Count 'Detailed status rows'
    Assert-Equal 'QueryStatus' $r[0].Type 'Empty timeline status row'
    Assert-Equal 'Error' $r[1].Status 'Failed timeline status row'
    Assert-True (@($r | ConvertTo-Csv -NoTypeInformation).Count -eq 3) 'CSV export failed'
}
Test-Case 'Detailed rows are sorted newest first and preserve comments' {
    $r = @(Get-RebootHistory Sort -EndTime $end -Detailed)
    Assert-Equal $t.AddHours(1) $r[0].TimeCreated 'Timeline order'
    Assert-Equal 'Patch window' $r[0].Comment 'Request comments'
}
Write-Output ('Passed {0} reboot-history regression checks on PowerShell {1}.' -f $script:Passed, $PSVersionTable.PSVersion)
