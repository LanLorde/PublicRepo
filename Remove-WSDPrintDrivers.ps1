$Printers = Get-Printer | Where-Object {$_.PortName -like "*WSD*"}
Foreach ($Printer in $Printers){

    Remove-PrinterDriver -RemoveFromDriverStore

}