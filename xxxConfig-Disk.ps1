<#
.Description
Post disk config activities. Meant for simple setup and not meant for a SQL MultiDisk setup. 

.Example
invoke-command -computername server1,server2,server3 -filepath xxxConfig-Disk.ps1

.Notes
Parmatertize forinput

#>
Get-Disk |
? {$_.partitionstyle -eq 'RAW'}|
initialize-disk -PartitionStyle 'GPT' -PassThru |
new-partition -assigndriveletter -useMaximumSize |
format-volume -FileSystem 'NTFS' -NewFileSystemLabel 'DATA' -confirm:$false
