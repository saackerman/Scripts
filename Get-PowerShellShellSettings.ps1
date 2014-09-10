<#
.Synopsis
   Get the WSMAN settings on server(s).
.DESCRIPTION
   Get the WSMAN settings on server(s).
.EXAMPLE
   get-powershellSettings.ps1
.EXAMPLE
   Another example of how to use this cmdlet
#>


$file = "wsmansettings.txt"
$servers = "server1","server2","server3" #list of servers.
foreach($server in $servers){

                                Connect-WSMan $server

                                Get-Item wsman:\$server\shell | Get-ChildItem | out-file $file -Append

                                Disconnect-WSMan $server

 

                            }#foreach 

invoke-item $file 
