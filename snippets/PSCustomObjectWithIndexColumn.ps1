function Update-PSCustomObjectWithIndexColumnSlow {
    # DO NOT USE THIS FUNCTION, IF YOU DON'T WANT YOUR SOURCE PSCUSUTOMOBJECT!!!
    # This one is slow.
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PSCustomObjectToBeModiefiedWithIndexColumn
    )
    return $PSCustomObjectToBeModiefiedWithIndexColumn | ForEach-Object -Begin { $i = 1 } -Process { 
        $obj = [PSCustomObject]@{ index = $i++ }
        $_.PSObject.Properties | ForEach-Object { $obj | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value }
        $obj
    }
}

function Update-PSCustomObjectWithIndexColumnFast {
    # DO NOT USE THIS FUNCTION, IF YOU DON'T WANT YOUR SOURCE PSCUSUTOMOBJECT!!!
    # This one is fast.
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PSCustomObjectToBeModiefiedWithIndexColumn
    )

    return $PSCustomObjectToBeModiefiedWithIndexColumn | ForEach-Object -Begin { $i = 1 } -Process {
        if (-not ($_.PSObject.Properties.Name -contains "index")) {
            $_ | Add-Member -MemberType NoteProperty -Name "index" -Value ($i++)
        }
        else {
            Throw("An index column can only be added if the elements do not yet have a column with the name index.")
        }
    }
}

function New-PSCustomObjectWithIndexColumn {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$SourcePSCustomObjectWithoutIndexColumn
    )
    # Serializing and Deserialize is needed, because otherwise the pscustomobject will not be copied completely.
    # But be careful. -->Note: However, weirdly, it does not keep the ordering of ordered hashtables.
    # Source: https://stackoverflow.com/questions/9204829/deep-copying-a-psobject
    $serialData = [System.Management.Automation.PSSerializer]::Serialize($SourcePSCustomObjectWithoutIndexColumn)
    $workingcopy = [System.Management.Automation.PSSerializer]::Deserialize($serialData)

    $i = 1
    $workingcopy | ForEach-Object {
        if (-not ($_.PSObject.Properties.Name -contains "index")) {
            $_ | Add-Member -MemberType NoteProperty -Name "index" -Value ($i++)
            return $_
        }
        else {
            Throw("An index column can only be added if the elements do not yet have a column with the name index.")
        }
    }
}
