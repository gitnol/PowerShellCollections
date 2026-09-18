<#
.SYNOPSIS
    Kopiert alle Mitglieder einer AD-Gruppe in eine andere.

.DESCRIPTION
    Liest die Mitglieder der Quellgruppe rekursiv aus und fuegt sie der
    Zielgruppe hinzu. Bereits vorhandene Mitglieder werden uebersprungen.

.NOTES
    Rekursiv heisst: verschachtelte Gruppen werden aufgeloest, es landen also
    die einzelnen Konten in der Zielgruppe, nicht die Untergruppen. Wer die
    Verschachtelung erhalten will, darf -Recursive nicht verwenden.

    Die Funktion heisst Copy-ADGroupMembers (Plural).
#>

function Copy-ADGroupMembers {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourceGroup,

        [Parameter(Mandatory = $true)]
        [string]$TargetGroup
    )

    $sourceMembers = Get-ADGroupMember -Identity $SourceGroup -Recursive

    foreach ($member in $sourceMembers) {
        try {
            Add-ADGroupMember -Identity $TargetGroup -Members $member.SamAccountName -ErrorAction Stop
            Write-Host "Hinzugefügt: $($member.SamAccountName) zu $TargetGroup"
        }
        catch {
            Write-Warning "Fehler beim Hinzufügen von $($member.SamAccountName): $_"
        }
    }
}
