<#
.Author 
Sean Ackerman 9.4.2014
.Description
Changes Powershell default settings based on needs.



#>

$file = "wsmansettings.txt"

$serversfromFile = Read-Host "Enter file name that has list of servers you want to work with" 

$servers = Get-Content $serversfromFile

 

foreach($server in $servers){

                                Connect-WSMan $server

                                #Get-Item wsman:\$server\shell | Get-ChildItem | out-file $file -Append
                                #Set-Item wsman:\$server\shell\AllowRemoteShellAccess                                                                                                                                                                                                                                           
                                #Set-Item wsman:\$server\shell\IdleTimeout                                                                                                                                                                                                                                                      
                                Set-Item wsman:\$server\shell\MaxConcurrentUsers 20
                                #Set-Item wsman:\$server\shell\MaxShellRunTime                                                                                                                                                                                                                                                  
                                #Set-Item wsman:\$server\shell\MaxProcessesPerShell                                                                                                                                                                                                                                          
                                Set-Item wsman:\$server\shell\MaxMemoryPerShellMB 512                                                                                                                                                                                                                                          
                                Set-Item wsman:\$server\shell\MaxShellsPerUser 20
                                Get-Item wsman:\$server\shell | Get-ChildItem | out-file $file -Append
                                Disconnect-WSMan $server

 

                            }#foreach

 

invoke-item $file 
