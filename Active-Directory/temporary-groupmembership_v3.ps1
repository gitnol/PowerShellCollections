<#
.SYNOPSIS
    Bietet eine grafische Benutzeroberfläche (GUI) zur Verwaltung von temporären 
    Active Directory-Gruppenmitgliedschaften mithilfe des PAM-Features.

.DESCRIPTION
    Dieses Skript ermöglicht es Administratoren, Benutzern für einen begrenzten Zeitraum
    Mitgliedschaften in AD-Gruppen zuzuweisen. Es listet bestehende temporäre 
    Mitgliedschaften auf und bietet Auswahlfelder für Benutzer, Gruppen und ein Ablaufdatum.

    Voraussetzungen:
    - Das ActiveDirectory PowerShell-Modul muss installiert sein.
    - Das Skript muss mit administrativen Rechten im Kontext der Domäne ausgeführt werden.
    - Das 'Privileged Access Management Feature' muss im AD Forest aktiviert sein.

.VERSION
    2.0 - Refactored by Gemini
    Version 1.2 Tastenkombinationen hinzufügt.
    Version 1.1 diverse Änderungen u.a. mehrfaches Hinzufügen bei laufendem Dialog // Mehrfachauswahl bei Listenfeld inkl STRG+C Funktion zum kopieren!
    Version 1.0 geklaut aus diversen Quellen und abgeändert durch M.Arnoldi am 10.08.2021

.AUTHOR
    Original by M.Arnoldi, Refactored for efficiency and readability.

    Quellen:
    https://www.windowspro.de/marcel-kueppers/windows-server-2016-temporaere-mitgliedschaft-administrativen-gruppen-konfigurieren
    https://www.windowspro.de/roland-eich/gruppenmitgliedschaft-active-directory-temporaer-zuweisen-powershell-gui
    ergänzt mit
    https://www.frankysweb.de/privileged-access-management-feature-zeitbegrenzte-gruppenzugehoerigkeit/
    
#>

#Requires -Modules ActiveDirectory
#Requires -RunAsAdministrator

# --- Initialisierung und Überprüfung ---

# Prüfen, ob das PAM-Feature im AD Forest aktiviert ist.
# Wenn nicht, wird eine Fehlermeldung angezeigt und das Skript beendet.
try {
    Write-Host "Prüfe, ob das 'Privileged Access Management Feature' aktiviert ist..."
    $pamFeature = Get-ADOptionalFeature -Identity 'Privileged Access Management Feature' -ErrorAction Stop
    if ($pamFeature.EnabledScopes.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Das 'Privileged Access Management Feature' ist nicht aktiviert. Das Skript wird beendet.", "Fehler", "OK", "Error")
        exit
    }
}
catch {
    [System.Windows.Forms.MessageBox]::Show("Das PAM-Feature konnte nicht überprüft werden. Stellen Sie sicher, dass das AD-Modul geladen ist und Sie ausreichende Berechtigungen haben.`n`nFehler: $($_.Exception.Message)", "Fehler", "OK", "Error")
    exit
}

# --- GUI Erstellung ---

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Formular erstellen
$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = 'Temporäre Gruppenmitgliedschaft verwalten'
$mainForm.Size = New-Object System.Drawing.Size(950, 500)
$mainForm.StartPosition = 'CenterScreen'
$mainForm.FormBorderStyle = 'FixedDialog'
$mainForm.MaximizeBox = $false

# --- GUI Elemente (Controls) ---

# Label für Benutzerauswahl
$userLabel = New-Object System.Windows.Forms.Label
$userLabel.Location = New-Object System.Drawing.Size(20, 20)
$userLabel.Size = New-Object System.Drawing.Size(200, 20)
$userLabel.Text = "Benutzer auswählen:"

# ComboBox (Dropdown) für Benutzer
$userComboBox = New-Object System.Windows.Forms.ComboBox
$userComboBox.Location = New-Object System.Drawing.Size(20, 40)
$userComboBox.Size = New-Object System.Drawing.Size(200, 20)
$userComboBox.DropDownStyle = 'DropDownList' # Verhindert freie Texteingabe

# Label für Gruppenauswahl
$groupLabel = New-Object System.Windows.Forms.Label
$groupLabel.Location = New-Object System.Drawing.Size(20, 70)
$groupLabel.Size = New-Object System.Drawing.Size(200, 20)
$groupLabel.Text = "Gruppe auswählen:"

# ComboBox (Dropdown) für Gruppen
$groupComboBox = New-Object System.Windows.Forms.ComboBox
$groupComboBox.Location = New-Object System.Drawing.Size(20, 90)
$groupComboBox.Size = New-Object System.Drawing.Size(200, 20)
$groupComboBox.DropDownStyle = 'DropDownList'

# Label für Datumsauswahl
$dateLabel = New-Object System.Windows.Forms.Label
$dateLabel.Location = New-Object System.Drawing.Size(20, 120)
$dateLabel.Size = New-Object System.Drawing.Size(200, 20)
$dateLabel.Text = "Gültig bis (Datum):"

# Kalender-Steuerelement
$expiryCalendar = New-Object System.Windows.Forms.MonthCalendar
$expiryCalendar.Location = New-Object System.Drawing.Size(20, 140)
$expiryCalendar.MaxSelectionCount = 1
$expiryCalendar.MinDate = (Get-Date).AddDays(1) # Mitgliedschaft muss in der Zukunft liegen

# Label für die Liste der aktuellen Mitgliedschaften
$listLabel = New-Object System.Windows.Forms.Label
$listLabel.Location = New-Object System.Drawing.Size(240, 20)
$listLabel.Size = New-Object System.Drawing.Size(680, 20)
$listLabel.Text = "Aktive temporäre Mitgliedschaften (STRG+C zum Kopieren):"

# ListBox zur Anzeige der temporären Mitgliedschaften
$membershipsListBox = New-Object System.Windows.Forms.ListBox
$membershipsListBox.Location = New-Object System.Drawing.Size(240, 40)
$membershipsListBox.Size = New-Object System.Drawing.Size(680, 350)
$membershipsListBox.SelectionMode = 'MultiExtended'

# "Hinzufügen"-Button
$addButton = New-Object System.Windows.Forms.Button
$addButton.Location = New-Object System.Drawing.Size(20, 365)
$addButton.Size = New-Object System.Drawing.Size(200, 25)
$addButton.Text = 'Mitgliedschaft hinzufügen'

# "Schließen"-Button
$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Location = New-Object System.Drawing.Size(20, 400)
$closeButton.Size = New-Object System.Drawing.Size(200, 25)
$closeButton.Text = 'Schließen'
$mainForm.CancelButton = $closeButton # Schließt Formular bei ESC

# Statusleiste am unteren Rand
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Size(240, 405)
$statusLabel.Size = New-Object System.Drawing.Size(400, 20)
$statusLabel.Text = "Initialisiere..."

# Alle Steuerelemente zum Formular hinzufügen (effizienter mit AddRange)
$mainForm.Controls.AddRange(@(
        $userLabel, $userComboBox, $groupLabel, $groupComboBox, $dateLabel, $expiryCalendar,
        $listLabel, $membershipsListBox, $addButton, $closeButton, $statusLabel
    ))

# --- Funktionen ---

# Funktion zum Laden und Anzeigen der aktuellen temporären Mitgliedschaften
function Update-MembershipList {
    $statusLabel.Text = "Lade temporäre Mitgliedschaften..."
    $mainForm.Refresh() # GUI aktualisieren, damit der Text sichtbar wird
    
    $membershipsListBox.Items.Clear()

    # OPTIMIERUNG: Anstatt alle Gruppen zu laden und dann einzeln abzufragen,
    # fragen wir nur Gruppen ab, die überhaupt Mitglieder haben, und holen uns die TTL-Info direkt.
    # Dies reduziert die AD-Anfragen dramatisch.
    $groupsWithMembers = Get-ADGroup -Filter 'Members -like "*"' -Properties SamAccountName, Member -ShowMemberTimeToLive

    # OPTIMIERUNG: Die Ausgabe der Schleife wird direkt in einer Variablen gesammelt,
    # anstatt += zu verwenden. Das ist deutlich performanter.
    $membershipStrings = foreach ($group in $groupsWithMembers) {
        foreach ($memberDN in $group.Member) {
            # Wir verarbeiten nur Mitglieder mit TTL-Informationen
            if ($memberDN -like "*<TTL=*>*") {
                # OPTIMIERUNG: Regex ist robuster und lesbarer als mehrfaches .split()
                if ($memberDN -match '<TTL=(?<seconds>\d+)>\,(?<dn>.*)') {
                    $ttlSeconds = $matches.seconds
                    $userDN = $matches.dn
                    
                    try {
                        $user = Get-ADUser -Identity $userDN -Properties SamAccountName -ErrorAction Stop
                        $expiryDate = (Get-Date).AddSeconds($ttlSeconds)
                        # Formatierter String für die Anzeige
                        "$($user.SamAccountName) -> $($group.SamAccountName) | Gültig bis: $($expiryDate.ToString('dd.MM.yyyy HH:mm:ss'))"
                    }
                    catch {
                        # Fehler abfangen, falls der Benutzer nicht gefunden wird (z.B. gelöscht)
                        Write-Warning "Benutzer mit DN '$userDN' konnte nicht gefunden werden."
                    }
                }
            }
        }
    }
    
    # Die sortierte Liste zur ListBox hinzufügen
    $membershipsListBox.Items.AddRange(($membershipStrings | Sort-Object))
    $statusLabel.Text = "Bereit."
}

# --- Event Handler (Aktionen bei Klick, Auswahl, etc.) ---

# Aktion für den "Hinzufügen"-Button
$addButton.Add_Click({
        # Validierung: Sicherstellen, dass Benutzer und Gruppe ausgewählt wurden
        if ([string]::IsNullOrEmpty($userComboBox.SelectedItem) -or [string]::IsNullOrEmpty($groupComboBox.SelectedItem)) {
            [System.Windows.Forms.MessageBox]::Show("Bitte wählen Sie sowohl einen Benutzer als auch eine Gruppe aus.", "Eingabe fehlt", "OK", "Warning")
            return # Funktion hier beenden
        }

        $selectedUser = $userComboBox.SelectedItem
        $selectedGroup = $groupComboBox.SelectedItem
        $expiryDate = $expiryCalendar.SelectionStart

        # Berechnung der verbleibenden Zeit in Minuten
        $timeSpan = New-TimeSpan -Start (Get-Date) -End $expiryDate
        $minutesToLive = $timeSpan.TotalMinutes
    
        # Zusätzliche Prüfung, ob das Datum wirklich in der Zukunft liegt
        if ($minutesToLive -le 0) {
            [System.Windows.Forms.MessageBox]::Show("Das ausgewählte Datum muss in der Zukunft liegen.", "Ungültiges Datum", "OK", "Warning")
            return
        }

        $statusLabel.Text = "Füge '$selectedUser' zur Gruppe '$selectedGroup' hinzu..."
    
        try {
            # AD-Befehl mit Fehlerbehandlung ausführen
            Add-ADGroupMember -Identity $selectedGroup -Members $selectedUser -MemberTimeToLive (New-TimeSpan -Minutes $minutesToLive) -ErrorAction Stop
        
            [System.Windows.Forms.MessageBox]::Show("Benutzer '$selectedUser' wurde erfolgreich zur Gruppe '$selectedGroup' hinzugefügt.`n`nGültigkeit bis: $($expiryDate.ToString('dd.MM.yyyy HH:mm:ss'))", "Erfolg", "OK", "Information")
        
            # WICHTIG: Liste aktualisieren, um die Änderung sofort anzuzeigen!
            Update-MembershipList
        }
        catch {
            # Detaillierte Fehlermeldung bei Problemen
            [System.Windows.Forms.MessageBox]::Show("Fehler beim Hinzufügen des Benutzers.`n`n$($_.Exception.Message)", "Fehler", "OK", "Error")
            $statusLabel.Text = "Fehler. Bereit für nächsten Versuch."
        }
    })

# Aktion für den "Schließen"-Button
$closeButton.Add_Click({
        $mainForm.Close()
    })

# Tastenkombination STRG+C zum Kopieren der ausgewählten Einträge in der ListBox
$membershipsListBox.add_KeyDown({
        if ($_.Control -and $_.KeyCode -eq 'C') {
            $clipboardText = $membershipsListBox.SelectedItems | Out-String
            [System.Windows.Forms.Clipboard]::SetText($clipboardText)
        }
    })


# --- Daten laden und Formular anzeigen ---

# Initiales Laden der Daten in die GUI
$mainForm.Add_Shown({
        $statusLabel.Text = "Lade Benutzer und Gruppen aus dem AD..."
        $mainForm.Cursor = [System.Windows.Forms.Cursors]::WaitCursor # Mauszeiger auf "Warten" setzen

        # Benutzer laden (Systemkonten herausfiltern)
        $users = Get-ADUser -Filter * -Properties SamAccountName |
        Where-Object { $_.Name -notmatch '^(HealthMailbox|SystemMailbox|DiscoverySearchMailbox|FederatedEmail|Migration\.|Exchange Online-ApplicationAccount|DefaultAccount|Gast)' } |
        Select-Object -ExpandProperty SamAccountName |
        Sort-Object
        $userComboBox.Items.AddRange($users)

        # Gruppen laden
        $groups = Get-ADGroup -Filter * | Select-Object -ExpandProperty SamAccountName | Sort-Object
        $groupComboBox.Items.AddRange($groups)

        # Liste der Mitgliedschaften aktualisieren
        Update-MembershipList
    
        $mainForm.Cursor = [System.Windows.Forms.Cursors]::Default # Mauszeiger zurücksetzen
        $statusLabel.Text = "Bereit."
    })


# Das Formular anzeigen und auf Benutzereingaben warten
[void]$mainForm.ShowDialog()

# Ressourcen nach dem Schließen des Formulars freigeben
$mainForm.Dispose()