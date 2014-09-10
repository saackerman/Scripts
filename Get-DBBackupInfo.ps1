#Requires -Version 3.0
function Get-DbBackupInfo {
<#
.SYNOPSIS
Returns database backup information for a Microsoft SQL Server database.
 
.DESCRIPTION
Get-DbBackupInfo is a function that returns database backup information for
one or more Microsoft SQL Server databases.
 
.PARAMETER ComputerName
The computer that is running Microsoft SQL Server that you’re targeting to
query database backup information for.
 
.PARAMETER InstanceName
The instance name of SQL Server to return database backup information for.
The default is the default SQL Server instance.
 
.PARAMETER DatabaseName
The database(s) to return backup information for. The default is all databases.
 
.EXAMPLE
Get-DbBackupInfo -ComputerName sql01
 
.EXAMPLE
Get-DbBackupInfo -ComputerName sql01 -DatabaseName master, msdb, model
 
.EXAMPLE
Get-DbBackupInfo -ComputerName sql01 -InstanceName MrSQL -DatabaseName master,msdb, model
 
.EXAMPLE
'master', 'msdb', 'model' | Get-DbBackupInfo -ComputerName sql01
 
.INPUTS
String
 
.OUTPUTS
PSCustomObject
#>
 
   [CmdletBinding()]
   param (
      [Parameter(Mandatory,
      ValueFromPipelineByPropertyName)]
      [Alias('ServerName','PSComputerName')]
      [string[]]$ComputerName,
 
      [Parameter(ValueFromPipelineByPropertyName)]
      [ValidateNotNullOrEmpty()]
      [string[]]$InstanceName = 'Default',
 
      [Parameter(ValueFromPipelineByPropertyName)]
      [ValidateNotNullOrEmpty()]
      [string[]]$DatabaseName = '*'
 
   )
 
   BEGIN {
      $problem = $false
      Write-Verbose -Message "Attempting to load SQL Module if it's not already loaded"
      if (-not (Get-Module -Name SQLPS)) {
          try {
              Import-Module -Name SQLPS -DisableNameChecking -ErrorAction Stop
          }
          catch {
              $problem = $true
              Write-Warning -Message "An error has occurred.  Error details: $_.Exception.Message"
          }
      }
   }
 
   PROCESS {
       foreach ($Computer in $ComputerName) {
            foreach ($Instance in $InstanceName) {
                Write-Verbose -Message 'Checking for default or named SQL instance'
                If (-not ($problem)) {
                    If (($Instance -eq 'Default') -or ($Instance -eq 'MSSQLSERVER')) {
                       $SQLInstance = $Computer
                    }
                    else {
                       $SQLInstance = "$Computer\$Instance"
                    }
                    $SQL = New-Object('Microsoft.SqlServer.Management.Smo.Server') -ArgumentList $SQLInstance
                }
 
                if (-not $problem) {
                     foreach ($db in $DatabaseName) {
                         Write-Verbose -Message "Verifying a database named: $db exists on SQL Instance $SQLInstance."
                         try {
                             if ($db -match '\*') {
                                  $databases = $SQL.Databases | Where-Object Name -like "$db"
                             }
                             else {
                                  $databases = $SQL.Databases | Where-Object Name -eq "$db"
                             }
                         }
                         catch {
                             $problem = $true
                             Write-Warning -Message "An error has occurred.  Error details: $_.Exception.Message"
                         }
                         if (-not $problem) {
                             foreach ($database in $databases) {
                                  Write-Verbose -Message "Retrieving information for database: $database."
                                  [PSCustomObject]@{
                                      ComputerName = $SQL.Information.ComputerNamePhysicalNetBIOS
                                      InstanceName = $Instance
                                      DatabaseName = $database.Name
                                      LastBackupDate = $database.LastBackupDate
                                      LastDifferentialBackupDate = $database.LastDifferentialBackupDate
                                      LastLogBackupDate = $database.LastLogBackupDate
                                      RecoveryModel = $database.RecoveryModel
                             }
                          }
                     }
                 }
             }
         }
      }
   }
}
 
Get-DbBackupInfo -ComputerName sql01 | Format-Table