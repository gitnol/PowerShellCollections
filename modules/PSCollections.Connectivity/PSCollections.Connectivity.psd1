@{
    RootModule        = 'PSCollections.Connectivity.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b6a7f3d2-4c1e-4a9b-9f57-2d8e41c0a6b3'
    Author            = 'Gitnol'
    Description       = 'Erreichbarkeitspruefung fuer viele Rechner - parallel (PowerShell 7) oder ueber Hintergrundjobs (Windows PowerShell 5.1).'
    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Test-ConnectionInParallel',
        'Get-ComputerOnlineStatus'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags = @('Network', 'Ping', 'Availability')
        }
    }
}
