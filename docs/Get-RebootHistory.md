# Get-RebootHistory 2.0

Dot-source the file to load the function. It reads events and does not restart,
reconfigure, or clear anything on a target computer.

```powershell
. .\Get-RebootHistory.ps1
Get-RebootHistory
Get-RebootHistory -ComputerName server01,server02 -Credential (Get-Credential)
'server01','server02' | Get-RebootHistory
Get-RebootHistory | Where-Object { $_.Status -eq 'Success' -and $_.PercentDirty -ge 30 }
Get-RebootHistory -StartTime (Get-Date).AddDays(-90) -Detailed |
    Export-Csv .\reboot-events.csv -NoTypeInformation
```

## Compatibility

Requires Windows PowerShell 5.1 or PowerShell 7 on Windows. Get-WinEvent queries the
Windows Event Log service directly using RPC; WinRM is not required. Remote targets
need appropriate event-log permissions and firewall rules. Local aliases omit the
Credential and ComputerName arguments, so they do not accidentally use remote RPC.

The original summary names remain: Computer, BootHistory, RecentShutdowns,
UnexpectedShutdowns, RecentUnexpected, PercentDirty, LastShutdown,
LastShutdownType, LastShutdownUser, LastShutdownProcess and LastShutdownReason.

These intentional output changes fix problems in version 1.1:

- PercentDirty is a numeric percentage, such as `5`, so `-ge 30` works correctly.
  PercentDirtyDisplay contains `5%` for display-only consumers.
- Dates are UTC DateTime objects with full event precision, not localized strings.
- UnexpectedShutdowns holds detection/startup timestamps. Windows can log a failure
  at its next startup, long after the actual failure. Detailed ReportedShutdownTime
  preserves the localized occurrence text from event 6008 without assuming the
  remote machine's culture or time zone.
- Missing planned shutdown events no longer suppress a computer's entire result.
- Query failures return Status=Error, Error text and null numeric counts. Empty
  history returns Status=NoEvents, zero counts and a null percentage.

LastShutdown is the latest User32 1074 **request**, not evidence that a shutdown
completed. RecentShutdowns retains its historical name but counts observed boots.
Recent counts cover RecentDays (default 30) ending at EndTime (default now).
StartTime defaults to all retained events. Changing the query window can remove
correlation evidence and changes the available denominator.

## Event interpretation

| Provider | ID | Interpretation |
|---|---:|---|
| Microsoft-Windows-Kernel-General | 12 | Operating-system startup |
| Microsoft-Windows-Kernel-General | 13 | Operating system shutting down |
| EventLog | 6009 | Startup fallback when no event 12 is nearby |
| EventLog | 6005 / 6006 | Event-log service start/stop, not independent boot counts |
| User32 | 1074 | Shutdown/restart request, process, user, reason and comment |
| Microsoft-Windows-Kernel-Power | 41 | Unexpected-shutdown detection |
| EventLog | 6008 | Unexpected-shutdown report, including localized occurrence text |
| Microsoft-Windows-WER-SystemErrorReporting | 1001 | Bugcheck report |

Events 12 and 6009 within five minutes count as one boot. Different legacy 6009
records remain separate if no event 12 is nearby. Unexpected signals associate with
a startup marker within five minutes, preferring preceding System-log record IDs.
Signals assigned to that marker share one IncidentId. Without a startup marker,
different unexpected signal IDs within five minutes can share an incident; repeated
signals of the same ID remain separate. This is a documented correlation heuristic,
not proof of causation, and heavily delayed logging or missing records can reduce
its accuracy. Event 41 alone does not identify a power supply or hardware fault.

BootCount, UnexpectedCount, LastBoot, query bounds and HistoryWarnings supplement
the original summary. A missing boot denominator produces a null percentage; fewer
boot markers than unexpected incidents produces a Partial result and a warning.
Retained logs and filtered windows cannot establish a computer's full lifetime history.

## Verification

```powershell
# Run once in Windows PowerShell 5.1 and once in PowerShell 7.
.\tests\Get-RebootHistory.Tests.ps1
```

The dependency-free suite uses synthetic local/remote event records and failures,
plus one read-only native System-log query. It tests multi-computer isolation,
credentials, percentages, date windows, duplicate signals, rapid boots, empty
history, failed targets, localized text and malformed event data. Actual remote
RPC connectivity requires a permitted target environment; fixtures do not prove it.

Original author attribution is retained in the script. No license was added.

References:

- [Microsoft reboot event guidance](https://learn.microsoft.com/en-us/troubleshoot/windows-server/performance/troubleshoot-unexpected-reboots-system-event-logs)
- [Get-WinEvent](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-winevent)
