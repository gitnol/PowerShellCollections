function Test-OleDbConnection {
    <#
    .SYNOPSIS
    Prüft eine OLE DB Datenbankverbindung mit interaktiver Passwortabfrage.
    #>

    param (
        [Parameter(Mandatory)]
        [string]$BaseConnectionString
    )

    $securePass = Read-Host 'Passwort aus KeePass eingeben' -AsSecureString
    $plainPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass)
    )

    $connectionString = "$BaseConnectionString;Password=$plainPass"

    $result = [PSCustomObject]@{
        Success = $false
        Message = $null
    }

    try {
        $conn = New-Object System.Data.OleDb.OleDbConnection $connectionString
        $conn.Open()
        $conn.Close()

        $result.Success = $true
        $result.Message = 'Verbindung erfolgreich.'
    }
    catch {
        $result.Message = $_.Exception.Message
    }
    finally {
        if ($conn) {
            $conn.Dispose()
        }
        $plainPass = $null
    }

    return $result
}

# Basis-Connectionstring OHNE Passwort
$baseConnectionString = 'Provider=SQLOLEDB.1;Persist Security Info=False;User ID=sa;Initial Catalog=MDM_DB;Data Source=MYSERVER\MYINSTANCE'

Test-OleDbConnection -BaseConnectionString $baseConnectionString
