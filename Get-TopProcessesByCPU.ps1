<#
.SYNOPSIS
    This script will list the top processes by CPU usage from highest to lowest.
.DESCRIPTION
    
.EXAMPLE
    Get-TopProcessesByCPU
    This will list the top processes by CPU usage from highest to lowest.
.EXAMPLE
    Invoke-Command -ComputerName Server01 -filepath C:\Scripts\Get-TopProcessesByCPU.ps1
.INPUTS
    
.OUTPUTS
    System.Diagnostics.Process
.NOTES
    File Name      : Get-TopProcessesByCPU.ps1
    Author         : Sean Ackerman
    Prerequisite   : PowerShell V5 +
    
.LINK
https://stackoverflow.com/questions/39943928/listing-processes-by-cpu-usage-percentage-in-powershell  #code credit
.TODO
    Parameterize get-counter to allow for different counters to be used. Will need to adjust the math to account for the different counters.
#>
$NumberOfLogicalProcessors = (Get-WmiObject -Class Win32_ComputerSystem).NumberOfLogicalProcessors
(Get-Counter '\Process(*)\% Processor Time').Countersamples | Sort cookedvalue -Desc | ft -a instancename, @{Name='CPU%';Expr={[Math]::Round($_.CookedValue / $NumberOfLogicalProcessors)}}
