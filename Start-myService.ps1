<#
.SYNOPSIS
    Verify a service is running and start it if it is not.
.DESCRIPTION
    This function will check if a service is running and start it if it is not.
.NOTES
    File Name      : Start-MyService.ps1
    Author         : Sean Ackerman
    Prerequisite   : PowerShell V5 +
    Test Platform  : Windows 10,11, Windows Server 2016,2019,2022
.LINK
    https://github.com/saackerman/Scripts/blob/master/Start-myService.ps1
    https://www.bing.com/chat?q=Microsoft+Copilot&FORM=hpcodx
.EXAMPLE
    Start-MyService -service 'wuauserv'
    This will check if the Windows Update service is running and start it if it is not.
.EXAMPLE
    invoke-command -ComputerName Server01 -filepath C:\Scripts\Start-MyService.ps1 -arguemntList 'wuauserv'
.ToDo
    Add logging to log aggreator or choice or local system.
#>

[CmdletBinding()]
    Param(
        [Parameter()
        HelpMessage='Enter the name of the service to check, default is wuauserv'
        ]
        [ValidateNotNullOrEmpty()]
        [string]$service='wuauserv'
        )

    begin{

        }#end begin
    Process {
        try {
        $service = Get-Service -Name $service
        if($service.Status -eq 'Running'){
            Write-Host "$service is running"
        }else{
            Write-Host "$service is not running, attempting to start"
            Start-Service -Name $service -Confirm:$false
        }
        } #end try
        
        catch {
        Write-Error -message "$_.Exception.Message"
        Write-Error -Message "Troubleshoot agent on server"
        # todo write to AppInsights or Log Analytics
        } #end catch
    }
    end{}
        
