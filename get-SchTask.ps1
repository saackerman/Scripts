#$taskPath = "\*"  use if you want all tasks at root folder and below
<#
.SYNOPSIS
    Returns a list of scheduled tasks
.DESCRIPTION
    This script will return a list of scheduled tasks on a local or remote computer.
.EXAMPLE
    PS C:\> get-SchTask.ps1
    Returns a list of all scheduled tasks on the local computer. 
.EXAMPLE
    PS C:\> get-SchTask.ps1 -taskPath "\Microsoft\Windows\Windows Defender"
    Returns a list of all scheduled tasks in the Windows Defender folder.
.EXAMPLE
    invoke-command -computername server1,server2,server3,server4 -filepath {get-SchTask.ps1}
    Returns a list of all scheduled tasks on the remote computers server1, server2, server3, and server4.
.PARAMETER taskPath
    The path to the folder containing the scheduled tasks. The default is "\*". Wildcards are supported. This will return all tasks in the root folder and below.
.INPUTS
    taskPath - The path to the folder containing the scheduled tasks. The default is "\*". 
.OUTPUTS
    tasksReport - A list of scheduled tasks
.NOTES
    General notes
#>


    [CmdletBinding()]
    param (

        [Parameter(Position=0, Mandatory=$false)]
        [string]$taskPath = "\*"
    )    
    
    
    begin {
        
    }
    
    process {
            
            $tasksReport = Get-ScheduledTask -TaskPath $taskPath | ForEach-Object { [pscustomobject]@{
    
                Name = $_.TaskName
    
                Path = $_.TaskPath
    
                LastResult = $(($_ | Get-ScheduledTaskInfo).LastTaskResult)
    
                NextRun = $(($_ | Get-ScheduledTaskInfo).NextRunTime)
    
                Status = $_.State
    
                Command = $_.Actions.execute
    
                Arguments = $_.Actions.Arguments 
    
                }#end taskReport pscustomobject
                $tasksReport
            }
    }
    
    end {
        Clear-Variable tasksReport
    }





