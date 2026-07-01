function Get-DirectoryListing {
    <#
        .SYNOPSIS
            Lists directory contents with human-readable file sizes, sorted by size.

        .DESCRIPTION
            A friendlier Get-ChildItem that displays Mode, Name, human-readable
            Length (KB/MB/GB/TB), and LastWriteTime. Sorted largest-first by default.
            Directories show empty size. Aliased as 'lsh' for quick use.

        .PARAMETER Path
            Directory to list. Defaults to current directory.

        .PARAMETER Ascending
            Sort smallest-first instead of largest-first.

        .EXAMPLE
            Get-DirectoryListing

            List current directory sorted by size (largest first).

        .EXAMPLE
            Get-DirectoryListing -Path 'C:\logs'

            List specific directory.

        .EXAMPLE
            lsh .\reports

            Using the alias.

        .EXAMPLE
            Get-DirectoryListing -Ascending

            Smallest files first.

        .NOTES
            Dot-source to load: . .\Get-DirectoryListing.ps1
            Then use: lsh, Get-DirectoryListing
    #>
    [CmdletBinding()]
    [Alias('lsh')]
    param (
        [Parameter(Position = 0)]
        [string]$Path = '.',

        [Parameter()]
        [switch]$Ascending
    )

    $SelectProperties = @{
        Property = @(
            'Mode'
            'Name'
            @{
                Name       = 'Size'
                Expression = {
                    if ($_.PSIsContainer) { '' }
                    else { $_.Length | Format-FileSize }
                }
            }
            'LastWriteTime'
        )
    }

    $SortDirection = if ($Ascending) { $false } else { $true }

    Get-ChildItem -Path $Path |
        Sort-Object Length -Descending:$SortDirection |
        Select-Object @SelectProperties
}


function Format-FileSize {
    <#
        .SYNOPSIS
            Converts bytes to human-readable size string.

        .PARAMETER Bytes
            File size in bytes.

        .EXAMPLE
            1048576 | Format-FileSize
            # Returns: "1.00 MB"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [int64]$Bytes
    )

    process {
        switch ($Bytes) {
            { $_ -ge 1TB } { '{0:N2} TB' -f ($_ / 1TB); break }
            { $_ -ge 1GB } { '{0:N2} GB' -f ($_ / 1GB); break }
            { $_ -ge 1MB } { '{0:N2} MB' -f ($_ / 1MB); break }
            { $_ -ge 1KB } { '{0:N2} KB' -f ($_ / 1KB); break }
            default        { "$_ Bytes" }
        }
    }
}
