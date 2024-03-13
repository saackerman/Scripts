<#
.Description
Get the computername of Microsoft.Web/sites/instancess. use this in combinations when their is a Azure service locking out its service account and cross reference against AD logs using the computername object in KQL/Azure Resource Graph.
.Requirements
Need Az powershell module installed.

.Source 
http://integryx.net/post/2020/04/16/powershell-script-to-retrieve-computer-names-for-your-azure-app-services , not this no longer is on the web as of 2022.
#>
$websites = Get-AzResource -ResourceType Microsoft.Web/sites
 
foreach($website in $websites) {
    $resoureGroupName = $website.ResourceGroupName
    $websiteName = $website.Name
    $instances = Get-AzResource -ResourceGroupName $resoureGroupName `
    -ResourceType Microsoft.Web/sites/instances `
    -ResourceName $websiteName `
    -ApiVersion 2018-02-01
 
    foreach($instance in $instances) {
        $instanceName = $instance.Name
         
        try {
            $processes = Get-AzResource -ResourceGroupName $resoureGroupName `
                -ResourceType Microsoft.Web/sites/instances/processes `
                -ResourceName $websiteName/$instanceName `
                -ApiVersion 2018-02-01 `
                -ErrorAction Ignore
            }
        catch { continue }
 
        foreach($process in $processes) {
            $processId = $process.Properties.id
             
            try {
                $processDetails = Get-AzResource -ResourceGroupName $resoureGroupName `
                    -ResourceType Microsoft.Web/sites/instances/processes `
                    -ResourceName $websiteName/$instanceName/$processId `
                    -ApiVersion 2018-02-01 `
                    -ErrorAction Ignore
                 
                if ($processDetails.Properties.environment_variables.COMPUTERNAME -ne $null) {
                    Write-Host $websiteName " : " $processDetails.Properties.environment_variables.COMPUTERNAME
                }
            } catch { }
       }
    }
} 

