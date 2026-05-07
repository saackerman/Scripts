function Get-FolderSize {
    <#
        .SYNOPSIS
            Gets the size of one or more folders including subdirectories.

        .DESCRIPTION
            Recursively measures folder size, file count, and subfolder count.
            Supports local and UNC paths. Results stored in $FolderSizeResults
            for later use.

        .PARAMETER Path
            One or more folder paths to measure. Accepts pipeline input.

        .PARAMETER Depth
            Limit recursion depth for reporting subfolders. Default reports
            only the top-level totals. Set to 1+ to see immediate children.

        .PARAMETER ComputerName
            Remote computer to query via Invoke-Command. Uses WinRM.

        .PARAMETER Credential
            Credential for remote access.

        .OUTPUTS
            System.Collections.Generic.List[PSCustomObject]
            Each object has Path, SizeMB, SizeGB, FileCount, FolderCount properties.

        .EXAMPLE
            Get-FolderSize -Path 'C:\Windows\Temp'

        .EXAMPLE
            Get-FolderSize -Path 'D:\Shares\Data', 'D:\Shares\Logs'

        .EXAMPLE
            Get-FolderSize -Path 'C:\inetpub' -ComputerName 'WebServer01'

        .EXAMPLE
            Get-FolderSize -Path 'C:\Users' -Depth 1

            Shows size of each immediate subfolder under C:\Users.

        .EXAMPLE
            Get-FolderSize -Path 'C:\Temp'
            $FolderSizeResults | Out-GridView

        .NOTES
            Results stored in $FolderSizeResults at script scope.
            Large directories may take time — use -Verbose for progress.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        # Folder path(s) to measure
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true,
            HelpMessage = "One or more folder paths to measure. Supports UNC paths.")]
        [ValidateNotNullOrEmpty()]
        [Alias('FullName', 'FolderPath')]
        [string[]]$Path,

        # Report immediate children at this depth (0 = top-level only)
        [Parameter()]
        [ValidateRange(0, 10)]
        [int]$Depth = 5,

        # Remote computer to query via WinRM
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias('CN')]
        [string]$ComputerName,

        # Credential for remote access
        [Parameter()]
        [PSCredential]$Credential
    )

    begin {
        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'

        $script:FolderSizeResults = [System.Collections.Generic.List[PSCustomObject]]::new()

        $MeasureBlock = {
            param ([string]$TargetPath, [int]$TargetDepth)

            $results = [System.Collections.Generic.List[PSCustomObject]]::new()

            function Measure-Folder {
                param ([string]$FolderPath)

                $items = Get-ChildItem -Path $FolderPath -Recurse -Force -ErrorAction SilentlyContinue
                $files = @($items | Where-Object { -not $_.PSIsContainer })
                $folders = @($items | Where-Object { $_.PSIsContainer })

                $totalSize = 0
                if ($files.Count -gt 0) {
                    $measured = $files | Measure-Object -Property Length -Sum
                    $totalSize = $measured.Sum
                }

                [PSCustomObject]@{
                    Path        = $FolderPath
                    SizeMB      = [math]::Round($totalSize / 1MB, 2)
                    SizeGB      = [math]::Round($totalSize / 1GB, 2)
                    FileCount   = $files.Count
                    FolderCount = $folders.Count
                }
            }

            # Measure the top-level path
            $results.Add((Measure-Folder -FolderPath $TargetPath))

            # Measure children if depth requested
            if ($TargetDepth -gt 0) {
                $children = Get-ChildItem -Path $TargetPath -Directory -Force -ErrorAction SilentlyContinue
                foreach ($child in $children) {
                    $results.Add((Measure-Folder -FolderPath $child.FullName))
                }
            }

            $results
        }
    }

    process {
        foreach ($FolderPath in $Path) {
            Write-Verbose "Measuring: $FolderPath"

            try {
                if ($ComputerName) {
                    $InvokeParams = @{
                        ComputerName = $ComputerName
                        ScriptBlock  = $MeasureBlock
                        ArgumentList = @($FolderPath, $Depth)
                        ErrorAction  = 'Stop'
                    }
                    if ($Credential) { $InvokeParams['Credential'] = $Credential }

                    $results = Invoke-Command @InvokeParams
                }
                else {
                    $results = & $MeasureBlock $FolderPath $Depth
                }

                foreach ($result in $results) {
                    $script:FolderSizeResults.Add($result)
                    $result
                }
            }
            catch {
                Write-Error "Failed to measure '$FolderPath': $_"
            }
        }
    }
}
