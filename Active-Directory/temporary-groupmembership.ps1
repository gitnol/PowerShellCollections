# Version 1.0 geklaut aus diversen Quellen und abgeändert durch M.Arnoldi am 10.08.2021
# Version 1.1 diverse Änderungen u.a. mehrfaches Hinzufügen bei laufendem Dialog // Mehrfachauswahl bei Listenfeld inkl STRG+C Funktion zum kopieren!
# Version 1.2 Tastenkombinationen hinzufügt.
# Quellen:
# https://www.windowspro.de/marcel-kueppers/windows-server-2016-temporaere-mitgliedschaft-administrativen-gruppen-konfigurieren
# https://www.windowspro.de/roland-eich/gruppenmitgliedschaft-active-directory-temporaer-zuweisen-powershell-gui
# ergänzt mit
# https://www.frankysweb.de/privileged-access-management-feature-zeitbegrenzte-gruppenzugehoerigkeit/

# Prüfen ob Privileded Access Management Feature aktiviert ist

If ((Get-ADOptionalFeature -Identity 'Privileged Access Management Feature').EnabledScopes.Count -eq 0) {
   
    $Result = [System.Windows.Forms.MessageBox]::Show("Das Feature Privileged Access Management Feature wurde nicht gefunden, das Programm wird nicht fortgeführt!", "Frage an den Benutzer", 0)
}
else {

    #Globale Befehle abschicken um User aus dem AD in $user zu laden (siehe dropdown)
    $user = Get-ADUser -Filter * -Properties SamAccountName |
    Where-Object { $_.Name -notmatch '^(HealthMailbox|SystemMailbox|DiscoverySearchMailbox|FederatedEmail|Migration\.|Exchange Online-ApplicationAccount|DefaultAccount|Gast)' } |
    Select-Object -ExpandProperty SamAccountName |
    Sort-Object

    # Write-Host($user)
    # Write-Host($user.count)



    #Globale Befehle abschicken um Gruppen aus dem AD in $gruppen zu laden (siehe dropdown)
    $Gruppen = Get-ADGroup -Filter * | Select -ExpandProperty SamAccountName | Sort-Object

    $MemberList = @()
    $testGesamt = @()
    #$MemberListGroupName=@()
    foreach ($gruppe in $Gruppen) {
        $GroupName = $gruppe
        $GroupMembers = (Get-ADGroup $GroupName -Property member -ShowMemberTimeToLive).Member
    
        foreach ($GroupMember in $GroupMembers) {
            if ($GroupMember -match "TTL=") {
                $TTL = $GroupMember.split(",")[0].split("=")[1].replace(">", "")
                $TTLDate = (Get-Date).AddSeconds($TTL)
                $MemberDN = $GroupMember.Split(">")[1].Replace(",CN", "CN")
                #$username = (Get-ADUser -Filter * -SearchBase "$MemberDN" | select Name)
                $username = (Get-ADUser -Filter * -SearchBase "$MemberDN")
                $test = new-object PSObject -property @{DN = $MemberDN; Group = $GroupName; TTLDate = "$TTLDate"; TTL = "$TTL" }
                $testGesamt += $username.Name + " -> " + $groupName + " bis " + $TTLDate.ToString("dd/MM/yyyy HH:mm:ss")
                #$test
                $MemberList += $username
                #$MemberListGroupName += $GroupName
                #$MemberList += $test
            }
            else {
                #$TTL = "Unlimited"
                #$TTLDate = "Unlimited"
                #$MemberDN = $GroupMember
                #$MemberList += new-object PSObject -property @{DN=$MemberDN;TTLDate="$TTLDate";TTL="$TTL"}
            }
        }
    }


    $MemberList = ($MemberList | Sort-Object) | select Name

    # GUI erstellen
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $objForm = New-Object Windows.Forms.Form
    $objForm = New-Object System.Windows.Forms.Form

    $objForm.Text = 'Temporäre Gruppenmitgliedschaft setzen'
    $objForm.Size = New-Object Drawing.Size @(1000, 490) # 490
    $objForm.StartPosition = 'CenterScreen'


    $objLabelLB = New-Object System.Windows.Forms.Label
    $objLabelLB.Location = New-Object System.Drawing.Size(240, 60) 
    $objLabelLB.Size = New-Object System.Drawing.Size(1000, 20) 
    $objLabelLB.Text = "Benutzer mit Gruppen-Limits (Mehrfachauswahl mit STRG; Kopieren mit STRG+C):"
    $objForm.Controls.Add($objLabelLB)
    #Listbox
    $objCurrentUserWithLimits = New-Object System.Windows.Forms.ListBox
    $objCurrentUserWithLimits.SelectionMode = 'MultiExtended'
    $objCurrentUserWithLimits.Location = New-Object System.Drawing.Point(240, 80); # ggf. size
    $objCurrentUserWithLimits.Height = 300
    $objCurrentUserWithLimits.Width = 700

    $testGesamt = $testGesamt | Sort-Object

    foreach ($item in $testGesamt) {
        # $item
        $objCurrentUserWithLimits.Items.Add($item) | Out-Null
    }

    $objForm.Controls.Add($objCurrentUserWithLimits) 

    $objCurrentUserWithLimits.add_KeyDown({
            if ($_.Control -and $_.KeyCode -eq 'C') {
                $txt = $objCurrentUserWithLimits.SelectedItems | Out-String
                [System.Windows.Forms.Clipboard]::SetText($txt)
                $objCurrentUserWithLimits.ClearSelected()    
            }
        })

    #Drop DownFeld für User

    #User aus dem Ad anzeigen

    $objLabel = New-Object System.Windows.Forms.Label
    $objLabel.Location = New-Object System.Drawing.Size(28, 60) 
    $objLabel.Size = New-Object System.Drawing.Size(1000, 20) 
    $objLabel.Text = "Bitte Benutzernamen wählen:"
    $objForm.Controls.Add($objLabel)

    $objCombobox = New-Object System.Windows.Forms.Combobox 
    $objCombobox.Location = New-Object System.Drawing.Size(30, 80) 
    $objCombobox.Size = New-Object System.Drawing.Size(200, 20) 
    $objCombobox.Height = 70
    $objForm.Controls.Add($objCombobox) 
    $objForm.Topmost = $True
    $objForm.Add_Shown({ $objForm.Activate() })
    $objCombobox.Items.AddRange($user) #User werden aus der Variable geladen und angezeigt
    $objCombobox.SelectedItem #ausgewählter Username wird übernommen
            
    #$objCombobox.Add_SelectedIndexChanged({ })


    #Drop DownFeld für Gruppen

    #User aus dem Ad anzeigen

    $objLabel = New-Object System.Windows.Forms.Label
    $objLabel.Location = New-Object System.Drawing.Size(28, 110) 
    $objLabel.Size = New-Object System.Drawing.Size(1000, 20) 
    $objLabel.Text = "Bitte Gruppennamen wählen:"
    $objForm.Controls.Add($objLabel) 

    $objCombobox1 = New-Object System.Windows.Forms.Combobox 
    $objCombobox1.Location = New-Object System.Drawing.Size(30, 130) 
    $objCombobox1.Size = New-Object System.Drawing.Size(200, 20) 
    $objCombobox1.Height = 70
    $objForm.Controls.Add($objCombobox1) 
    $objForm.Topmost = $True
    $objForm.Add_Shown({ $objForm.Activate() })
    $objCombobox1.Items.AddRange($gruppen) #User werden aus der Variable geladen und angezeigt
    $objCombobox1.SelectedItem #ausgewählter Username wird übernommen
            
    #$objCombobox.Add_SelectedIndexChanged({ })


    #Kalender
    $objLabel = New-Object System.Windows.Forms.Label
    $objLabel.Location = New-Object System.Drawing.Size(28, 180) 
    $objLabel.Size = New-Object System.Drawing.Size(1000, 20) 
    $objLabel.Text = "Enddatum wählen:"
    $objForm.Controls.Add($objLabel) 
    $calendar = New-Object System.Windows.Forms.MonthCalendar
    $calendar.Location = New-Object System.Drawing.Point(28, 200)
    $calendar.Size = New-Object System.Drawing.Size(175, 25)
    $calendar.ShowTodayCircle = $false
    $calendar.MaxSelectionCount = 1
    $objForm.Controls.Add($calendar)

    #OK Button
    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point(28, 400)
    $OKButton.Size = New-Object System.Drawing.Size(75, 25)
    $OKButton.Text = 'O&K (ALT+K)'
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $OKButton.Add_Click({

            # Message setzen und Gruppe dem Benutzer hinzufügen bzw. abprüfen

            $mgm1 = "Der ausgewählte Benutzer", $objCombobox.SelectedItem, "ist bereits in der ausgewählten Gruppe", $objCombobox1.SelectedItem, "enthalten!"
            $mgm2 = "Benutzer wurde in die Gruppe", $objCombobox1.SelectedItem, "hinzugefügt! Gültigkeit bis", $calendar.SelectionStart

            if (Get-ADGroupMember $objCombobox1.SelectedItem | Where-Object { $_.SamAccountName -eq $objCombobox.SelectedItem }) {

                $Result = [System.Windows.Forms.MessageBox]::Show($mgm1, "Frage an den Benutzer", 0)
            }
            else {
                $Tag1 = $calendar.SelectionStart
                $Tag2 = Get-Date
                $Tag = ($Tag1 - $Tag2).TotalMinutes

                Add-ADGroupMember -Identity $objCombobox1.SelectedItem -Members $objCombobox.SelectedItem -MemberTimeToLive (New-TimeSpan -Minutes $Tag)

                $Result = [System.Windows.Forms.MessageBox]::Show($mgm2, "Frage an den Benutzer", 0)
            }

        })

    $objForm.AcceptButton = $OKButton
    $objForm.Controls.Add($OKButton)


    #Abbrechen Button
    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Point(125, 400)
    $CancelButton.Size = New-Object System.Drawing.Size(100, 25)
    $CancelButton.Text = '&Cancel (ALT+C)'
    $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $objForm.CancelButton = $CancelButton
    $objForm.Controls.Add($CancelButton)

    $objForm.Topmost = $true


    #Hinzufügen Button
    $HinzufButton = New-Object System.Windows.Forms.Button
    $HinzufButton.Location = New-Object System.Drawing.Point(28, 370)
    $HinzufButton.Size = New-Object System.Drawing.Size(200, 25)
    $HinzufButton.Text = '+ &hinzufügen (ALT+H)'
    #$HinzufButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $HinzufButton.Add_Click({

            # Message setzen und Gruppe dem Benutzer hinzufügen bzw. abprüfen

            If ([string]::IsNullOrEmpty($objCombobox1.SelectedItem) -or [string]::IsNullOrEmpty($objCombobox.SelectedItem)) {
                $Result = [System.Windows.Forms.MessageBox]::Show("Bitte Benutzer und Gruppe auswählen!", "Frage an den Benutzer", 0)
            }
            else {
                $mgm1 = "Der ausgewählte Benutzer", $objCombobox.SelectedItem, "ist bereits in der ausgewählten Gruppe", $objCombobox1.SelectedItem, "enthalten!"
                $mgm2 = "Benutzer wurde in die Gruppe", $objCombobox1.SelectedItem, "hinzugefügt! Gültigkeit bis", $calendar.SelectionStart
    
                if (Get-ADGroupMember $objCombobox1.SelectedItem | Where-Object { $_.SamAccountName -eq $objCombobox.SelectedItem }) {
    
                    $Result = [System.Windows.Forms.MessageBox]::Show($mgm1, "Frage an den Benutzer", 0)
                }
                else {
                    $Tag1 = $calendar.SelectionStart
                    $Tag2 = Get-Date
                    $Tag = ($Tag1 - $Tag2).TotalMinutes
                    if ([convert]::ToInt32($Tag) -ge 0) {
                        # Nur Tage in der Zukunft akzeptieren.
                        Add-ADGroupMember -Identity $objCombobox1.SelectedItem -Members $objCombobox.SelectedItem -MemberTimeToLive (New-TimeSpan -Minutes $Tag)
                        $Result = [System.Windows.Forms.MessageBox]::Show($mgm2, "Frage an den Benutzer", 0)
                        $item = ($objCombobox.SelectedItem + ' -> ' + $objCombobox1.SelectedItem + " bis " + $Tag1)
                        $objCurrentUserWithLimits.Items.Add($item)
                    }
                    else {
                        $Result = [System.Windows.Forms.MessageBox]::Show("Bitte einen Tag in der Zukunft auswählen!", "Frage an den Benutzer", 0)
                    }
                }
            }


        })

    $objForm.Controls.Add($HinzufButton)



    $result = $objForm.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $date = $calendar.SelectionStart
        $date
        Write-Host "Date selected: $($date.ToShortDateString())"
    }

}
