# SecureBoot Zertifikat-Prüfung und -Update – Enterprise-Leitfaden

## Hintergrund und Handlungsbedarf

Microsoft führt ein neues UEFI-Zertifikat ein: **Windows UEFI CA 2023** ersetzt das auslaufende **Windows UEFI CA 2011**. Ab **Januar 2026** werden Windows Updates das alte 2011-Zertifikat über die DBX (Revocation List) widerrufen. Systeme, die dann:

- Secure Boot **aktiv** haben, **und**
- das 2023er Zertifikat **nicht** in der UEFI-DB eingetragen haben,

werden nach dem Update **nicht mehr booten**.

Systeme ohne Secure Boot sind kurzfristig nicht gefährdet, haben aber geringeren Schutz.

---

## Überblick: Welches Skript wofür

| Skript | Zweck | Ausführungsort | Modus |
|---|---|---|---|
| `Check-MultipleHostsSecureBoot.ps1` | Inventar aller AD-Server | Verwaltungs-PC | Remote, parallel |
| `Test-SecureBootCert2023.ps1` | Schnelltest Einzelsystem | lokal auf dem Zielrechner | nur lesen |
| `Invoke-SecureBootCertUpdate.ps1 -Status` | Detaillierter Status (genauer) | lokal oder remote | nur lesen |
| `Invoke-SecureBootCertUpdate.ps1 -AutoConfirm` | Update automatisch einleiten | remote via `Invoke-Command` | schreibend |
| `Invoke-SecureBootCertUpdate_simple.ps1` | Sofort-Update manuell | lokal auf dem Zielrechner | schreibend |
| `Check-UEFISecureBootVariables-main\` | Tiefenanalyse UEFI-Variablen | lokal auf dem Zielrechner | nur lesen |

---

## Schritt 1: Inventar – welche Systeme sind betroffen?

### Server-Inventar (AD-basiert)

Das Skript `Check-MultipleHostsSecureBoot.ps1` prüft automatisch alle aktiven Windows-Server aus dem Active Directory:

```powershell
# Ausführen auf einem Verwaltungs-PC mit AD-Zugriff und PowerShell 7+
# Erfordert: RSAT, Netzwerkzugriff auf die Zielhosts (WinRM/5985)
.\Check-MultipleHostsSecureBoot.ps1
```

**Was es tut:**
1. Ruft alle aktiven Server aus dem AD ab (`Get-ADComputer`)
2. Prüft den Online-Status parallel (bis zu 20 gleichzeitig)
3. Führt `Invoke-SecureBootCertUpdate.ps1 -Status` remote auf allen erreichbaren Servern aus
4. Zeigt das Ergebnis als Grid-Ansicht (`Out-GridView`)

**Ausgabe-Felder (PSCustomObject je Server):**

| Feld | Bedeutung |
|---|---|
| `ComputerName` | Hostname |
| `Phase` | Fortschrittsphase (8 = fertig, 0 = noch nicht geprüft) |
| `SecureBootEnabled` | Secure Boot aktiv? |
| `UEFICA2023InDB` | 2023er Zertifikat vorhanden? |
| `Success` | Letzter Schritt erfolgreich? |
| `Message` | Erklärung / nächste Aktion |
| `RebootRequired` | Neustart ausstehend? |
| `ServicingStatus` | Windows-interner Update-Status |
| `TaskExists` | Scheduled Task `Secure-Boot-Update` vorhanden? |

**Kritische Kombination = Handlungsbedarf:**
```
SecureBootEnabled = True  UND  UEFICA2023InDB = False
```

### Client-Inventar

`Check-MultipleHostsSecureBoot.ps1` prüft standardmäßig nur Server. Für Clients den AD-Filter in Zeile 17 anpassen:

```powershell
# Nur Server (Standard):
$adComputers = Get-ADComputer -Filter 'OperatingSystem -like "*Windows Server*" -and Enabled -eq $true' -Properties LastLogonDate, OperatingSystem

# Alle Windows-Systeme (Server + Clients):
$adComputers = Get-ADComputer -Filter 'OperatingSystem -like "*Windows*" -and Enabled -eq $true' -Properties LastLogonDate, OperatingSystem

# Nur Clients:
$adComputers = Get-ADComputer -Filter 'OperatingSystem -like "*Windows 10*" -or OperatingSystem -like "*Windows 11*"' -Properties LastLogonDate, OperatingSystem
```

---

## Schritt 2: Einzelsystem prüfen

### Einfacher Schnelltest (lokal)

```powershell
# Als Administrator ausführen
.\Test-SecureBootCert2023.ps1
```

Gibt ein Objekt zurück:

| Status | Bedeutung |
|---|---|
| `OK` + `Cert2023Present = True` | System sicher, Zertifikat vorhanden |
| `OK` + `SecureBootEnabled = False` | Secure Boot inaktiv, kurzfristig kein Boot-Risiko |
| `GEFAHR` | Secure Boot aktiv, 2023er Zertifikat **fehlt** – Handlungsbedarf! |
| `KEIN_UEFI` | Legacy-BIOS-System, Secure Boot nicht verfügbar |
| `FEHLER` | UEFI DB konnte trotz Adminrechten nicht gelesen werden |

### Detaillierter Status (lokal oder remote)

```powershell
# Lokal:
.\Invoke-SecureBootCertUpdate.ps1 -Status

# Remote auf einem einzelnen Host:
Invoke-Command -ComputerName "HOSTNAME" -ScriptBlock {
    & "\\ServerFreigabe\Scripts\Invoke-SecureBootCertUpdate.ps1" -Status
}
```

---

## Schritt 3: Update einleiten

> **Voraussetzungen vor jedem Update:**
> - VM-Snapshot erstellen (Quiesce: Ja, Memory: Nein)
> - Wartungsfenster einplanen (1–2 Neustarts erforderlich)
> - Auf physischen Systemen: **Power Off + Power On** statt Warm-Reboot bevorzugen
> - **BitLocker:** Die Skripte setzen BitLocker automatisch aus (siehe unten)

### Einzelsystem – manuell (lokal)

```powershell
# Einfache Variante (setzt 0x5944, alle Updates auf einmal):
.\Invoke-SecureBootCertUpdate_simple.ps1

# Einfache Variante ohne interaktive Neustart-Abfrage (auch remote nutzbar):
.\Invoke-SecureBootCertUpdate_simple.ps1 -AutoConfirm

# Kontrollierte Variante (Phase-für-Phase mit Abfragen):
.\Invoke-SecureBootCertUpdate.ps1
```

### Massenbetrieb – remote auf mehreren Systemen

```powershell
$ScriptContent = Get-Content ".\Invoke-SecureBootCertUpdate.ps1" -Raw
$TargetHosts = @("SERVER01", "SERVER02", "CLIENT01")

$Results = Invoke-Command -ComputerName $TargetHosts -ThrottleLimit 20 -ScriptBlock {
    $sbi = [scriptblock]::Create($using:ScriptContent)
    & $sbi -AutoConfirm
} -ErrorAction SilentlyContinue

# Auswertung:
$Results | Select-Object ComputerName, Phase, UEFICA2023InDB, Success, RebootRequired, Message | Out-GridView
```

> **Wichtig bei Remote-Betrieb:** Wenn `-AutoConfirm` einen Reboot auslöst, bricht die Remote-Session vor der Rückgabe des Ergebnisobjekts ab. Reboots daher besser separat planen (z.B. über SCCM/Intune, WOL oder `Restart-Computer` im separaten Job).

---

## Update-Phasen von `Invoke-SecureBootCertUpdate.ps1`

Das Skript erkennt automatisch, in welcher Phase sich ein System befindet:

| Phase | Name | Bedeutung |
|---|---|---|
| 0 | Vorprüfung | Erster Aufruf, Task-Existenz wird geprüft |
| 1 | Snapshot bestätigen | Warte auf Bestätigung, dass VM-Snapshot erstellt wurde |
| 2 | Ist-Zustand prüfen | Prüft ob Zertifikat schon vorhanden ist |
| 3 | Registry + Task | Setzt `AvailableUpdates = 0x40`, startet den Windows-Task |
| 4 | Reboot 1 ausstehend | Neustart 1 erforderlich |
| 5 | Nach Reboot 1 | Zwischenzustand wird geprüft |
| 6 | Reboot 2 ausstehend | Zweiter Neustart erforderlich (bei altem Task-Mechanismus) |
| 7 | Endergebnis prüfen | Verifiziert ob Zertifikat erfolgreich eingetragen wurde |
| 8 | Abgeschlossen | Zertifikat in DB, kein Handlungsbedarf |
| 99 | Warte-Phase | Script wurde zu früh nach Reboot 1 gestartet |

**Direktzugriff auf State-Datei (für Debugging):**
```
C:\ProgramData\SecureBootUpdate\state.json
C:\ProgramData\SecureBootUpdate\update.log
```

**Fortschritt zurücksetzen:**
```powershell
.\Invoke-SecureBootCertUpdate.ps1 -Reset -AutoConfirm
```

---

## Tiefenanalyse einzelner Systeme (Check-UEFISecureBootVariables-main)

Für detaillierte Analyse der UEFI-Variablen (PK, KEK, DB, DBX) steht das externe Tool zur Verfügung. **Lokal auf dem Zielsystem als Administrator ausführen:**

| Skript/CMD | Zweck |
|---|---|
| `ps\Check UEFI PK, KEK, DB and DBX.ps1` | Alle UEFI-Variablen lesbar ausgeben, inkl. DBX-Prüfung |
| `ps\Dump-SecureBootData.ps1` | Alle Daten als XML exportieren (`SecureBootData.xml` auf Desktop) |
| `ps\Find-EfiFilesRevokedByDbx.ps1` | EFI-Binaries auf revozierte Hashes prüfen |

```powershell
# Exportierten Status maschinell auswerten:
$data = Import-Clixml "$env:USERPROFILE\Desktop\SecureBootData.xml"
$data.RegistryKeys.Servicing.UEFICA2023Status
$data.DBX.SecurityVersionNumber.BootMgr.Version.ToString()
```

---

## Voraussetzungen

| Anforderung | Details |
|---|---|
| PowerShell | 7+ für parallele AD-Abfrage (`Check-MultipleHostsSecureBoot.ps1`), 5.1+ für Einzelskripte |
| Rechte | Lokaler Administrator auf Zielrechner; Domänen-Admin für Remote-Betrieb |
| WinRM | Muss auf Zielhosts aktiv sein (`winrm quickconfig`) |
| AD-Modul | RSAT: `Install-WindowsFeature RSAT-AD-PowerShell` (Server) oder `Add-WindowsCapability -Name Rsat.ActiveDirectory*` (Client) |
| UEFI | Kein BIOS-Legacy-Modus; `Confirm-SecureBootUEFI` muss ausführbar sein |

---

## BitLocker

Das Eintragen des 2023er Zertifikats in die UEFI-DB ändert den Inhalt von **PCR 7** (Platform Configuration Register), den BitLocker für die TPM-Versiegelung nutzt. Ohne Gegenmaßnahme fordert BitLocker beim ersten Boot nach dem Update die **48-stellige Recovery-Key-Eingabe**.

**Beide Skripte (`Invoke-SecureBootCertUpdate.ps1` und `Invoke-SecureBootCertUpdate_simple.ps1`) setzen BitLocker automatisch aus**, bevor sie die Registry ändern:

```powershell
# Was die Skripte intern tun (Suspend-BitLockerForUpdate):
Get-BitLockerVolume | Where-Object { $_.ProtectionStatus -eq 'On' } | ForEach-Object {
    Suspend-BitLocker -MountPoint $_.MountPoint -RebootCount 2
}
```

`RebootCount 2` ist notwendig weil der Update-Prozess **zwei Neustarts** benötigen kann. Das Ergebnisobjekt enthält das Feld `BitLockerSuspended` ($true/$false).

**Nach dem Suspend gilt:**
- BitLocker ist nicht deaktiviert, nur für 2 Neustarts ausgesetzt (Schlüssel liegt temporär ungeschützt vor, Disk bleibt verschlüsselt)
- Nach dem zweiten Neustart aktiviert sich BitLocker automatisch wieder mit den neuen PCR-Werten
- Tritt dennoch Recovery auf: Recovery-Key aus dem MBAM-Portal / Intune / AD auslesen

**Wenn `BitLockerSuspended = False` im Ergebnis:**
Der Suspend ist fehlgeschlagen (z.B. BitLocker-Feature nicht installiert, Rechtefehler). In diesem Fall das System manuell vorbereiten:
```powershell
Suspend-BitLocker -MountPoint "C:" -RebootCount 2
```

---

## Häufige Probleme

**`UEFICA2023InDB = False` nach abgeschlossenem Update:**
- Wurde statt Power Off + Power On nur ein Soft-Reboot (Neustart) gemacht? → Physischen Power-Cycle durchführen
- `WindowsUEFICA2023Capable = 0` in der Registry? → Das Skript setzt automatisch einen Workaround (nur wenn Hardware tatsächlich fähig ist)

**Task `Secure-Boot-Update` nicht gefunden (`TaskExists = False`):**
- Windows-Updates sind veraltet → Zuerst Windows Updates einspielen
- Gilt insbesondere für ältere Windows-10-Builds

**Remote-Verbindung schlägt fehl:**
```powershell
# WinRM-Status prüfen:
Test-WSMan -ComputerName "HOSTNAME"
# WinRM aktivieren (auf Zielhost als Admin):
winrm quickconfig
```

**Script meldet `Phase 8` aber Zertifikat scheint zu fehlen:**
- State-Datei ist veraltet → `Invoke-SecureBootCertUpdate.ps1 -Reset -AutoConfirm` und erneut prüfen

---

## Referenzen

- [KB5036210: Windows UEFI CA 2023 Deployment](https://support.microsoft.com/en-gb/topic/kb5036210-deploying-windows-uefi-ca-2023-certificate-to-secure-boot-allowed-signature-database-db-a68a3eae-292b-4224-9490-299e303b450b)
- [Secure Boot Certificate updates: Guidance for IT professionals](https://support.microsoft.com/en-us/topic/secure-boot-certificate-updates-guidance-for-it-professionals-and-organizations-e2b43f9f-b424-42df-bc6a-8476db65ab2f)
- [How to manage Boot Manager revocations (CVE-2023-24932)](https://support.microsoft.com/en-us/topic/how-to-manage-the-windows-boot-manager-revocations-for-secure-boot-changes-associated-with-cve-2023-24932-41a975df-beb2-40c1-99a3-b3ff139f832d)
- [Registry key updates for Secure Boot (IT-managed)](https://support.microsoft.com/en-us/topic/registry-key-updates-for-secure-boot-windows-devices-with-it-managed-updates-a7be69c9-4634-42e1-9ca1-df06f43f360d)
- [Check-UEFISecureBootVariables (externes Tool)](https://github.com/cjee21/Check-UEFISecureBootVariables)
