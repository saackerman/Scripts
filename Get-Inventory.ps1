<#
	.SYNOPSIS
		Windows Machine Inventory Using PowerShell. Use to validate SACM SNOW discovery to augment information in the CMDB.

	.DESCRIPTION
		This script is to document the Windows machine with machiens at WMF 5.1. 
		This script will work for Local or remote execution if powershell remoting is enabled. Tested on server 2008, 2012, 2016, 2019, 2022, Windows 7, 10, 11
		Use this if you are going  into a situation to validate the information receive is accurate then continue to triage the incident.

	.EXAMPLE
	Local
 	PS C:\> .\inventory.PS1
  	Remotely
        icm -ComputerName ($servers.name) -FilePath inventory.ps1

	.OUTPUTS
		HTML File OutPut ReportDate , General Information , BIOS Information etc.
	.NOTES
	You can convert gwmi to the CIM commands. Note I did kept wmi for backwards compatibility when using on older OSes. 2008,2012. IIRC CIM works on Linux/OSX if powershell 
	is enabled but I have not seen in practice in the enterprise for Linux distrobutions.
	.LINK
	https://github.com/saackerman/Scripts/blob/master/Get-Inventory.ps1
#>
#change email parameters.
$smtp = "smtp.yourDomain.com"
$to = "you@yourDomain.com"
$from = "machine@info.com"

$inventory = Get-Item -Path C:\inventory
New-Item -ItemType directory -Path $inventory -ErrorAction SilentlyContinue
Set-Location $inventory


$UserName = $env:USERNAME   
$ComputerName = $env:COMPUTERNAME

#css change as needed
$a = "<style>"
$a = $a + "BODY{font-size:11pt;background-color:lightgrey;}"
$a = $a + "TH{background-color:black;color:white}"
$a = $a + "TD{background-color:#19aff0;color:black;}"
$a = $a + "</style>"

#ReportDate
$ReportDate = Get-Date | Select-Object -Property DateTime
$date = $ReportDate.DateTime

#change to Cimstance down the road for all get-wmiobject 
#General Information
$ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem | Select-Object Model , Manufacturer , Description , PrimaryOwnerName , SystemType | ConvertTo-Html -Fragment
$baseboard = Get-WmiObject Win32_BaseBoard  |  Select-Object Name,Manufacturer,Product,SerialNumber | ConvertTo-Html -Fragment

#Boot Configuration
$BootConfiguration = Get-WmiObject -Class Win32_BootConfiguration |Select-Object Name , ConfigurationPath   | ConvertTo-Html -Fragment

#BIOS Information
$BIOS = Get-WmiObject -Class Win32_BIOS | Select-Object Manufacturer, SerialNumber , Version  | ConvertTo-Html -Fragment

#Operating System Information
$OS = Get-WmiObject -Class Win32_OperatingSystem | Select-Object-Object Caption , OSArchitecture , OSLanguage  | ConvertTo-Html -Fragment
#$OS = Get-CimInstance -ClassName win32_operatingsystem | Select-Object Caption , OSArchitecture , OSLanguage, LastBootUpTime, InstallDate  

#Time Zone Information
$TimeZone = Get-WmiObject -Class Win32_TimeZone | Select-Object-Object Caption , StandardName | ConvertTo-Html -Fragment

#CPU Information
$SystemProcessor = Get-WmiObject -Class Win32_Processor  | Select-Object-Object Name , deviceid, numberofcores, MaxClockSpeed , Manufacturer , status | ConvertTo-Html -Fragment

#Memory Information
#$PhysicalMemory = Get-WmiObject -Class Win32_Computersystem | Select-Object -Property Tag , SerialNumber , PartNumber , Manufacturer , DeviceLocator , @{Name="Capacity(GB)";Expression={"{0:N1}" -f ($_.Capacity/1GB)}}  
$PhysicalMemory = Get-WmiObject -Class Win32_Computersystem | Select-Object Tag, @{Name='Capacity(GB)';Expression={"{0:N0}" -f ($_.TotalPhysicalMemory/1GB)}} | ConvertTo-Html -Fragment

#Nic Information
$ipinfo=Get-WmiObject Win32_NetworkAdapterConfiguration | Select-Object @{Name='IPAddress';Expression={$_.IpAddress -join '; '}},MACAddress,@{Name='IPSubnet';Expression={$_.IPSubnet -join '; '}},@{Name='Gateway';Expression={$_.DefaultIPGateway -join '; '}},@{Name='DNS Servers';Expression={$_.DNSServerSearchOrder -join '; '}},Caption | Where-Object {$_.IPaddress -notlike ""} | ConvertTo-Html -Fragment

#Volume
$volume = Get-WmiObject Win32_Volume -Filter "DriveType='3'" | ForEach-Object {
    New-Object PSObject -Property @{
        Name = $_.Name
        Label = $_.Label
        FreeSpace_GB = ([Math]::Round($_.FreeSpace /1GB,2))
        TotalSize_GB = ([Math]::Round($_.Capacity /1GB,2))
    }
} | ConvertTo-Html -Fragment
#services , uncomment and adjust as needed.
<#
$services = Get-Service | where {$_.DisplayName -like "*AvP*" -or $_.DisplayName -like "*AgentVx*"}
$services = $services | Select-Object Displayname, status |sort DisplayName | ConvertTo-Html -Fragment
#>

#Software installed.
<#
$Software = Get-WmiObject -Class Win32_Product | Select-Object Name , Vendor , Version , Caption
$Software | sort name  | ConvertTo-Html -Fragment
#>

#email format
#<font color = blue><H4><B>Software Inventory</B></H4></font>$Software
$emailbody = ConvertTo-Html -head $a -Body "<font color = blue><H4><B>Inventory Report for $ComputerName on $Date by $UserName</B></H4></font>
<font color = blue><H4><B>General Information</B></H4></font>$ComputerSystem
<font color = blue><H4><B>General Information</B></H4></font>$baseboard
<font color = blue><H4><B>BISO</B></H4></font>$bios
<font color = blue><H4><B>General Information</B></H4></font>$BootConfiguration
<font color = blue><H4><B>Operating System Information</B></H4></font>$OS
<font color = blue><H4><B>Processor Information</B></H4></font>$SystemProcessor
<font color = blue><H4><B>Memory Information</B></H4></font>$PhysicalMemory
<font color = blue><H4><B>Volumes</B></H4></font>$volume  
<font color = blue><H4><B>Network Information</B></H4></font>$ipinfo
<font color = blue><H4><B>Time Zone Information</B></H4></font>$TimeZone 
<font color = blue><H4><B>Services check</B></H4></font>$services" 

#Leave a copy on machine.
$emailbody |  Out-File $outfile

#email
#Send-MailMessage -To $to -From $from -Subject "$ComputerName" -Attachments "$FilePath\$ComputerName.html" -SmtpServer $smtp
#Send-MailMessage -To $to -From $from -Subject "$ComputerName Inventory Report" -BodyAsHtml "$emailbody" -SmtpServer $smtp
Write-Host "Script Execution Completed" -ForegroundColor Yellow



#Move-Item -Path "$FilePath\$ComputerName.html" -Destination "$inventory"
