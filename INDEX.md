# Skript-Index

<!-- Automatisch erzeugt von tools/Build-ScriptIndex.ps1 - nicht von Hand bearbeiten. -->

163 Skripte, davon 48 mit `.SYNOPSIS` (29%).

## `_inbox/playground/`

| Skript | Beschreibung |
| ------ | ------------ |
| [New-ADGroupInOU_with_some_stuff.ps1](_inbox/playground/New-ADGroupInOU_with_some_stuff.ps1) | _keine .SYNOPSIS_ |

## `scripts/active-directory/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Protect-OUs.ps1](scripts/active-directory/Protect-OUs.ps1) | Aktiviert den Schutz vor versehentlichem Löschen für alle OUs in der Domäne. |
| [Test-DomainCredentials.ps1](scripts/active-directory/Test-DomainCredentials.ps1) | _keine .SYNOPSIS_ |

## `scripts/active-directory/dns/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Find-DNSDuplicates.ps1](scripts/active-directory/dns/Find-DNSDuplicates.ps1) | Findet und entfernt doppelte DNS-A-Einträge zonenübergreifend. |

## `scripts/active-directory/gpo/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Create-GPOAnalysis.ps1](scripts/active-directory/gpo/Create-GPOAnalysis.ps1) | _keine .SYNOPSIS_ |
| [Get-GPO_GPP_ItemLevelTargeting.ps1](scripts/active-directory/gpo/Get-GPO_GPP_ItemLevelTargeting.ps1) | _keine .SYNOPSIS_ |
| [Get-GPOLinks.ps1](scripts/active-directory/gpo/Get-GPOLinks.ps1) | _keine .SYNOPSIS_ |
| [Get-GPOReportSettings.ps1](scripts/active-directory/gpo/Get-GPOReportSettings.ps1) | _keine .SYNOPSIS_ |

## `scripts/active-directory/group-membership/`

| Skript | Beschreibung |
| ------ | ------------ |
| [compare-aduser-groups.ps1](scripts/active-directory/group-membership/compare-aduser-groups.ps1) | _keine .SYNOPSIS_ |
| [Copy-ADGroupMember.ps1](scripts/active-directory/group-membership/Copy-ADGroupMember.ps1) | _keine .SYNOPSIS_ |
| [Get-RecursiveGroupSIDs-Vergleich-zu-Get-ADPrincipalGroupMembership.ps1](scripts/active-directory/group-membership/Get-RecursiveGroupSIDs-Vergleich-zu-Get-ADPrincipalGroupMembership.ps1) | _keine .SYNOPSIS_ |
| [resolve-ad-groups-recursively.ps1](scripts/active-directory/group-membership/resolve-ad-groups-recursively.ps1) | _keine .SYNOPSIS_ |

## `scripts/active-directory/group-membership/temporary/`

| Skript | Beschreibung |
| ------ | ------------ |
| [temp_gruppenmitgliedschaft_bearbeiten_v2.ps1](scripts/active-directory/group-membership/temporary/temp_gruppenmitgliedschaft_bearbeiten_v2.ps1) | Automatisiert temporäre Active Directory-Gruppenmitgliedschaften für Auszubildende und andere Benutzer basierend auf Abteilungszuordnungen. |
| [temp_gruppenmitgliedschaft_bearbeiten_v3.ps1](scripts/active-directory/group-membership/temporary/temp_gruppenmitgliedschaft_bearbeiten_v3.ps1) | Automatisiert temporäre und permanente Active Directory-Gruppenmitgliedschaften basierend auf CSV-Dateien. |
| [temporary-groupmembership_v2.ps1](scripts/active-directory/group-membership/temporary/temporary-groupmembership_v2.ps1) | _keine .SYNOPSIS_ |
| [temporary-groupmembership.ps1](scripts/active-directory/group-membership/temporary/temporary-groupmembership.ps1) | _keine .SYNOPSIS_ |

## `scripts/active-directory/inventory/`

| Skript | Beschreibung |
| ------ | ------------ |
| [AD-Computer-Inventory-Parallel.ps1](scripts/active-directory/inventory/AD-Computer-Inventory-Parallel.ps1) | Inventarisiert AD-Computer parallel und aktualisiert Benutzer-, Hardware- und Kommentar-Informationen im Description-Feld. |
| [Get-ADComputerLastLogon.ps1](scripts/active-directory/inventory/Get-ADComputerLastLogon.ps1) | _keine .SYNOPSIS_ |
| [Get-ADUserLastLogonCache.ps1](scripts/active-directory/inventory/Get-ADUserLastLogonCache.ps1) | _keine .SYNOPSIS_ |
| [get-enabled_ad_user_with_managers.ps1](scripts/active-directory/inventory/get-enabled_ad_user_with_managers.ps1) | _keine .SYNOPSIS_ |
| [get-inactive-user-of-specific-group.ps1](scripts/active-directory/inventory/get-inactive-user-of-specific-group.ps1) | _keine .SYNOPSIS_ |

## `scripts/active-directory/ldap/`

| Skript | Beschreibung |
| ------ | ------------ |
| [LDAPServer.ps1](scripts/active-directory/ldap/LDAPServer.ps1) | _keine .SYNOPSIS_ |
| [Test-LdapPorts.ps1](scripts/active-directory/ldap/Test-LdapPorts.ps1) | _keine .SYNOPSIS_ |

## `scripts/active-directory/logon-events/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Get-ADAuthEventsAllDCs.ps1](scripts/active-directory/logon-events/Get-ADAuthEventsAllDCs.ps1) | Sammelt Anmelde-Events (fehlgeschlagen, Lockout, erfolgreich) von allen Domain Controllern inkl. Quell-IP. |
| [Get-LockedOutEventsAllDCs.ps1](scripts/active-directory/logon-events/Get-LockedOutEventsAllDCs.ps1) | Sammelt Account-Lockout-Events von allen Domain Controllern in der Domäne. |
| [Get-LogonAttempts.ps1](scripts/active-directory/logon-events/Get-LogonAttempts.ps1) | _keine .SYNOPSIS_ |
| [get-user-logons.ps1](scripts/active-directory/logon-events/get-user-logons.ps1) | _keine .SYNOPSIS_ |

## `scripts/active-directory/machine-sid/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Check-MachineSID.ps1](scripts/active-directory/machine-sid/Check-MachineSID.ps1) | Prüft den Online-Status von AD-Computern und führt optional einen Neustart oder eine SID-Prüfung durch. |
| [Get-DuplicateMachineSIDs.ps1](scripts/active-directory/machine-sid/Get-DuplicateMachineSIDs.ps1) | _keine .SYNOPSIS_ |

## `scripts/active-directory/time-sync/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Set-TimeSync.ps1](scripts/active-directory/time-sync/Set-TimeSync.ps1) | Konfiguriert die Zeitsynchronisierung für den PDC-Emulationsmaster korrekt. Besser ist es jedoch, wenn eine GPO für die Zeitsynchronisierung verwendet wird. |

## `scripts/active-directory/token-size/`

| Skript | Beschreibung |
| ------ | ------------ |
| [_dump-ticketsize.1.7.ps1](scripts/active-directory/token-size/_dump-ticketsize.1.7.ps1) | _keine .SYNOPSIS_ |
| [_Get-TokenSizeReport.ps1](scripts/active-directory/token-size/_Get-TokenSizeReport.ps1) | _keine .SYNOPSIS_ |

## `scripts/active-directory/user-photo/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Set-UserPhotoHybrid.ps1](scripts/active-directory/user-photo/Set-UserPhotoHybrid.ps1) | _keine .SYNOPSIS_ |

## `scripts/applications/docuware/`

| Skript | Beschreibung |
| ------ | ------------ |
| [IIS-Analyse-DocuWare.ps1](scripts/applications/docuware/IIS-Analyse-DocuWare.ps1) | Gibt alle IIS-Logzeilen der letzten X Minuten als PSCustomObject zurück (alle Felder). |

## `scripts/applications/excel/`

| Skript | Beschreibung |
| ------ | ------------ |
| [excel-to-pscustomobject.ps1](scripts/applications/excel/excel-to-pscustomobject.ps1) | _keine .SYNOPSIS_ |
| [Remove-ExcelSheetProtection_v4.ps1](scripts/applications/excel/Remove-ExcelSheetProtection_v4.ps1) | Entfernt den Blattschutz (Worksheet Protection) aus einer oder mehreren Tabellen einer .xlsx-Datei durch direkte XML-Manipulation. |

## `scripts/applications/filezilla/`

| Skript | Beschreibung |
| ------ | ------------ |
| [FileZilla.ps1](scripts/applications/filezilla/FileZilla.ps1) | _keine .SYNOPSIS_ |
| [Get-FtpLoginSummary.ps1](scripts/applications/filezilla/Get-FtpLoginSummary.ps1) | _keine .SYNOPSIS_ |

## `scripts/applications/kyocera/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Get-PrinterOID.ps1](scripts/applications/kyocera/Get-PrinterOID.ps1) | _keine .SYNOPSIS_ |

## `scripts/applications/openscape-business/`

| Skript | Beschreibung |
| ------ | ------------ |
| [OZBiz-Functions.psm1](scripts/applications/openscape-business/OZBiz-Functions.psm1) | Meldet sich an der OSBiz API an und gibt die Session-ID zurück. |

## `scripts/applications/teams/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Clear-TeamsCache.ps1](scripts/applications/teams/Clear-TeamsCache.ps1) | _keine .SYNOPSIS_ |

## `scripts/applications/teamviewer/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Parse-TeamViewerLogFile.ps1](scripts/applications/teamviewer/Parse-TeamViewerLogFile.ps1) | _keine .SYNOPSIS_ |
| [Set-TeamViewerAccess.ps1](scripts/applications/teamviewer/Set-TeamViewerAccess.ps1) | _keine .SYNOPSIS_ |
| [TeamViewer-Wrapper.ps1](scripts/applications/teamviewer/TeamViewer-Wrapper.ps1) | Startet TeamViewer mit verschiedenen Konfigurationsoptionen und Verbindungsparametern. |

## `scripts/applications/zammad/`

| Skript | Beschreibung |
| ------ | ------------ |
| [MoreAPITests.ps1](scripts/applications/zammad/MoreAPITests.ps1) | _keine .SYNOPSIS_ |
| [OnceMoreAPITests.ps1](scripts/applications/zammad/OnceMoreAPITests.ps1) | _keine .SYNOPSIS_ |
| [SomeAPITests.ps1](scripts/applications/zammad/SomeAPITests.ps1) | _keine .SYNOPSIS_ |

## `scripts/databases/mssql/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Check-DbConnection.ps1](scripts/databases/mssql/Check-DbConnection.ps1) | Prüft eine OLE DB Datenbankverbindung mit interaktiver Passwortabfrage. |
| [Get-SqlServerVersion.ps1](scripts/databases/mssql/Get-SqlServerVersion.ps1) | Ermittelt die Versionen von SQL Server Instanzen auf remote Servern. |

## `scripts/filesystem/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Compress-FilesByMonth.ps1](scripts/filesystem/Compress-FilesByMonth.ps1) | _keine .SYNOPSIS_ |
| [Get-DLLVersion.ps1](scripts/filesystem/Get-DLLVersion.ps1) | _keine .SYNOPSIS_ |
| [Resolve-Links.ps1](scripts/filesystem/Resolve-Links.ps1) | _keine .SYNOPSIS_ |

## `scripts/filesystem/permissions/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Fileserver-Einzelberechtigungen-fuer-User.ps1](scripts/filesystem/permissions/Fileserver-Einzelberechtigungen-fuer-User.ps1) | _keine .SYNOPSIS_ |
| [Get-FolderPermissions.ps1](scripts/filesystem/permissions/Get-FolderPermissions.ps1) | _keine .SYNOPSIS_ |

## `scripts/filesystem/search/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Find-FilesInZips.ps1](scripts/filesystem/search/Find-FilesInZips.ps1) | Durchsucht ZIP-Archive nach Dateien basierend auf einem Suchmuster. |
| [Get-TextMatchInFiles.ps1](scripts/filesystem/search/Get-TextMatchInFiles.ps1) | _keine .SYNOPSIS_ |

## `scripts/messaging/exchange/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Get-MailBoxForwardingRules.ps1](scripts/messaging/exchange/Get-MailBoxForwardingRules.ps1) | _keine .SYNOPSIS_ |
| [Manage-SharedMailboxPermissions.ps1](scripts/messaging/exchange/Manage-SharedMailboxPermissions.ps1) | _keine .SYNOPSIS_ |
| [New-SharedMailboxWorkflow.ps1](scripts/messaging/exchange/New-SharedMailboxWorkflow.ps1) | _keine .SYNOPSIS_ |

## `scripts/messaging/mailstore/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Get-MailStore-API-Function-Reference.ps1](scripts/messaging/mailstore/Get-MailStore-API-Function-Reference.ps1) | _keine .SYNOPSIS_ |
| [Mailstore-Scripts.ps1](scripts/messaging/mailstore/Mailstore-Scripts.ps1) | _keine .SYNOPSIS_ |
| [Mailstore-Scripts2.ps1](scripts/messaging/mailstore/Mailstore-Scripts2.ps1) | _keine .SYNOPSIS_ |
| [MailStoreFunctionsFromAPI.ps1](scripts/messaging/mailstore/MailStoreFunctionsFromAPI.ps1) | _keine .SYNOPSIS_ |
| [test.ps1](scripts/messaging/mailstore/test.ps1) | _keine .SYNOPSIS_ _(Achtung: 6 Parserfehler)_ |

## `scripts/messaging/mailstore/api-wrapper/`

| Skript | Beschreibung |
| ------ | ------------ |
| [MS.PS.Lib.psm1](scripts/messaging/mailstore/api-wrapper/MS.PS.Lib.psm1) | _keine .SYNOPSIS_ |

## `scripts/messaging/mailstore/examples/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Example1.ps1](scripts/messaging/mailstore/examples/Example1.ps1) | _keine .SYNOPSIS_ |
| [Example2.ps1](scripts/messaging/mailstore/examples/Example2.ps1) | _keine .SYNOPSIS_ |
| [Example3.ps1](scripts/messaging/mailstore/examples/Example3.ps1) | _keine .SYNOPSIS_ |
| [Example4.ps1](scripts/messaging/mailstore/examples/Example4.ps1) | _keine .SYNOPSIS_ |

## `scripts/messaging/nospamproxy/`

| Skript | Beschreibung |
| ------ | ------------ |
| [user-to-domain-communication.ps1](scripts/messaging/nospamproxy/user-to-domain-communication.ps1) | _keine .SYNOPSIS_ |

## `scripts/messaging/outlook/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Manage-OutlookAddins.ps1](scripts/messaging/outlook/Manage-OutlookAddins.ps1) | Verwaltet Outlook Add-ins (Status prüfen, Listen, Reparieren). |

## `scripts/monitoring/ping-monitor/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Start-Win10PingMonitor.ps1](scripts/monitoring/ping-monitor/Start-Win10PingMonitor.ps1) | _keine .SYNOPSIS_ |
| [Win10PingMonitor.psm1](scripts/monitoring/ping-monitor/Win10PingMonitor.psm1) | Schreibt Meldungen in eine Log-Datei |

## `scripts/monitoring/prtg/ad-group-integrity/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Check-ADGroupIntegrity-Multi.ps1](scripts/monitoring/prtg/ad-group-integrity/Check-ADGroupIntegrity-Multi.ps1) | _keine .SYNOPSIS_ |
| [Check-ADGroupIntegrity.ps1](scripts/monitoring/prtg/ad-group-integrity/Check-ADGroupIntegrity.ps1) | Überwacht die Integrität einer AD-Gruppe für PRTG und setzt einen Alarm (Latch/Breach) bei Änderungen. |

## `scripts/monitoring/prtg/dsls/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Get-DslsLicenseUsage.ps1](scripts/monitoring/prtg/dsls/Get-DslsLicenseUsage.ps1) | PRTG-Sensor: Lizenznutzung und Restlaufzeit je Komponente auf dem DSLS. |
| [Get-DslsLogError.ps1](scripts/monitoring/prtg/dsls/Get-DslsLogError.ps1) | PRTG-Sensor: Anzahl der Fehlermeldungen im DSLS-Log der letzten 24 Stunden. |
| [Get-DslsOfflineLicense.ps1](scripts/monitoring/prtg/dsls/Get-DslsOfflineLicense.ps1) | PRTG-Sensor: Anzahl der aktuell vergebenen Offline-Lizenzen (Nomad) auf dem DSLS. |
| [PRTG.Dsls.psm1](scripts/monitoring/prtg/dsls/PRTG.Dsls.psm1) | Gemeinsame Hilfsfunktionen fuer die DSLS-Sensoren (Dassault Systemes License Server). |

## `scripts/monitoring/web-changes/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Monitor-Webchanges.ps1](scripts/monitoring/web-changes/Monitor-Webchanges.ps1) | _keine .SYNOPSIS_ |

## `scripts/network/aruba/`

| Skript | Beschreibung |
| ------ | ------------ |
| [aruba.ps1](scripts/network/aruba/aruba.ps1) | _keine .SYNOPSIS_ |
| [aruba1.ps1](scripts/network/aruba/aruba1.ps1) | _keine .SYNOPSIS_ |

## `scripts/network/dhcp/`

| Skript | Beschreibung |
| ------ | ------------ |
| [get-dhcpserver-leases_v2.ps1](scripts/network/dhcp/get-dhcpserver-leases_v2.ps1) | _keine .SYNOPSIS_ |
| [get-dhcpserver-leases.ps1](scripts/network/dhcp/get-dhcpserver-leases.ps1) | _keine .SYNOPSIS_ |

## `scripts/network/diagnostics/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Get-WebHeaders.ps1](scripts/network/diagnostics/Get-WebHeaders.ps1) | Liest HTTP Response-Header und Statuscode aus. |
| [Show-NetConnections.ps1](scripts/network/diagnostics/Show-NetConnections.ps1) | Zeigt aktive TCP/UDP-Verbindungen inkl. Prozessinformationen, ähnlich netstat -anob. |
| [test-port.ps1](scripts/network/diagnostics/test-port.ps1) | _keine .SYNOPSIS_ |

## `scripts/network/firewall/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Cleanup-Firewall-Rules.ps1](scripts/network/firewall/Cleanup-Firewall-Rules.ps1) | _keine .SYNOPSIS_ |

## `scripts/network/lancom/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Create-PublicSpotUsers_old.ps1](scripts/network/lancom/Create-PublicSpotUsers_old.ps1) | Erstellt Public Spot Benutzer für LANCOM WLC/Router in Massenverarbeitung basierend auf einer CSV-Datei. |
| [Create-PublicSpotUsers.ps1](scripts/network/lancom/Create-PublicSpotUsers.ps1) | Erstellt Public Spot Benutzer für LANCOM WLC/Router in Massenverarbeitung basierend auf einer CSV-Datei. |
| [New-PublicSpotUser.ps1](scripts/network/lancom/New-PublicSpotUser.ps1) | Registers a new Public Spot user via a REST API call to a specified server. |

## `scripts/network/wake-on-lan/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Set-WakeOnLAN-AdapterOptions.ps1](scripts/network/wake-on-lan/Set-WakeOnLAN-AdapterOptions.ps1) | _keine .SYNOPSIS_ |
| [Wake-On-Lan.ps1](scripts/network/wake-on-lan/Wake-On-Lan.ps1) | Sendet ein Wake-on-LAN Magic Packet an eine MAC-Adresse. |

## `scripts/security/bitlocker/`

| Skript | Beschreibung |
| ------ | ------------ |
| [bitlocker-status-de.ps1](scripts/security/bitlocker/bitlocker-status-de.ps1) | _keine .SYNOPSIS_ |
| [bitlocker-status-en.ps1](scripts/security/bitlocker/bitlocker-status-en.ps1) | _keine .SYNOPSIS_ |

## `scripts/security/certificates/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Generate-Certificate.ps1](scripts/security/certificates/Generate-Certificate.ps1) | _keine .SYNOPSIS_ |
| [Replace-VMWare-Certificates.ps1](scripts/security/certificates/Replace-VMWare-Certificates.ps1) | _keine .SYNOPSIS_ |
| [Request-Certificate.ps1](scripts/security/certificates/Request-Certificate.ps1) | Requests a certificate from a Windows CA |

## `scripts/security/crowdstrike/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Install-FalconSensor.ps1](scripts/security/crowdstrike/Install-FalconSensor.ps1) | Kopiert eine Installationsdatei (z.B. FalconSensor) auf Zielcomputer und führt sie dort remote mit Parametern aus. Das Skript muss als Administrator ausgeführt werden. |

## `scripts/security/log4j/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Suche_nach_log4j_Dateien_optimiert.ps1](scripts/security/log4j/Suche_nach_log4j_Dateien_optimiert.ps1) | _keine .SYNOPSIS_ |
| [Suche_nach_log4j_Dateien.ps1](scripts/security/log4j/Suche_nach_log4j_Dateien.ps1) | _keine .SYNOPSIS_ |

## `scripts/security/passwords/`

| Skript | Beschreibung |
| ------ | ------------ |
| [check-for-bad-passwords.ps1](scripts/security/passwords/check-for-bad-passwords.ps1) | _keine .SYNOPSIS_ |

## `scripts/security/secure-boot/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Check-MultipleHostsSecureBoot.ps1](scripts/security/secure-boot/Check-MultipleHostsSecureBoot.ps1) | _keine .SYNOPSIS_ |
| [Invoke-SecureBootCertUpdate_simple.ps1](scripts/security/secure-boot/Invoke-SecureBootCertUpdate_simple.ps1) | _keine .SYNOPSIS_ |
| [Invoke-SecureBootCertUpdate.ps1](scripts/security/secure-boot/Invoke-SecureBootCertUpdate.ps1) | _keine .SYNOPSIS_ |
| [Test-MultipleHostsSecureBoot.ps1](scripts/security/secure-boot/Test-MultipleHostsSecureBoot.ps1) | _keine .SYNOPSIS_ |
| [Test-SecureBootCert2023.ps1](scripts/security/secure-boot/Test-SecureBootCert2023.ps1) | _keine .SYNOPSIS_ |

## `scripts/virtualization/vmware/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Create-Windows-VM-vSphere-Template.ps1](scripts/virtualization/vmware/Create-Windows-VM-vSphere-Template.ps1) | Bereitet eine Windows-VM als vSphere-Template vor. |
| [Get-VMSnapshots.ps1](scripts/virtualization/vmware/Get-VMSnapshots.ps1) | _keine .SYNOPSIS_ |
| [Get-VMUptimes.ps1](scripts/virtualization/vmware/Get-VMUptimes.ps1) | _keine .SYNOPSIS_ |

## `scripts/windows/activity-timeline/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Get-PCActivityTimeline.ps1](scripts/windows/activity-timeline/Get-PCActivityTimeline.ps1) | _keine .SYNOPSIS_ |
| [Test-PCActivityTimeline.ps1](scripts/windows/activity-timeline/Test-PCActivityTimeline.ps1) | _keine .SYNOPSIS_ |

## `scripts/windows/autoruns/`

| Skript | Beschreibung |
| ------ | ------------ |
| [autoruns2pwsh.ps1](scripts/windows/autoruns/autoruns2pwsh.ps1) | PowerShell script to manage Windows startup entries using Sysinternals Autoruns |

## `scripts/windows/availability/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Get-ComputerOnlineStatus_Alternative.ps1](scripts/windows/availability/Get-ComputerOnlineStatus_Alternative.ps1) | Prüft den Online-Status von Computern aus Active Directory und listet deren IP-Adressen auf. |
| [Get-ComputerOnlineStatus.ps1](scripts/windows/availability/Get-ComputerOnlineStatus.ps1) | _keine .SYNOPSIS_ |

## `scripts/windows/cleanup/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Clear-OldTempFiles_v2.ps1](scripts/windows/cleanup/Clear-OldTempFiles_v2.ps1) | Erweiterte Windows-Bereinigung für temporäre Dateien und Cache-Verzeichnisse |
| [Clear-OldTempFiles_v3.ps1](scripts/windows/cleanup/Clear-OldTempFiles_v3.ps1) | Erweiterte Windows-Bereinigung für temporäre Dateien und Cache-Verzeichnisse |
| [Clear-OldTempFiles_v4.ps1](scripts/windows/cleanup/Clear-OldTempFiles_v4.ps1) | Ultimate Windows Cleanup Tool v4.0 (Fixed) - Stabile Version |
| [Clear-OldTempFiles.ps1](scripts/windows/cleanup/Clear-OldTempFiles.ps1) | Gibt eine Liste bereinigungswürdiger Verzeichnispfade zurück. Bezieht sowohl systemweite als auch benutzerspezifische Pfade ein. |
| [remove-old-user-profiles.ps1](scripts/windows/cleanup/remove-old-user-profiles.ps1) | _keine .SYNOPSIS_ |

## `scripts/windows/desktop/window-cascade/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Set-ForegroundWindows_v2.ps1](scripts/windows/desktop/window-cascade/Set-ForegroundWindows_v2.ps1) | Skript zur Wiederherstellung der "Fenster überlappend anzeigen"-Funktion unter Windows 11. |
| [Set-ForegroundWindows.ps1](scripts/windows/desktop/window-cascade/Set-ForegroundWindows.ps1) | Skript zur Wiederherstellung der "Fenster überlappend anzeigen"-Funktion unter Windows 11. |

## `scripts/windows/elevation/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Elevate.ps1](scripts/windows/elevation/Elevate.ps1) | _keine .SYNOPSIS_ |
| [Elevate(Old).ps1](scripts/windows/elevation/Elevate(Old).ps1) | _keine .SYNOPSIS_ |

## `scripts/windows/eventlog/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Clear-Eventlog.ps1](scripts/windows/eventlog/Clear-Eventlog.ps1) | _keine .SYNOPSIS_ |
| [Setup-EventLog.ps1](scripts/windows/eventlog/Setup-EventLog.ps1) | Erstellt die Event Log-Quelle für ProcessMonitorService |
| [Simple-EventLog-Setup.ps1](scripts/windows/eventlog/Simple-EventLog-Setup.ps1) | _keine .SYNOPSIS_ |

## `scripts/windows/inventory/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Get-ClientMonitorEDIDData.ps1](scripts/windows/inventory/Get-ClientMonitorEDIDData.ps1) | _keine .SYNOPSIS_ |
| [Get-DiskInformation.ps1](scripts/windows/inventory/Get-DiskInformation.ps1) | _keine .SYNOPSIS_ |
| [Get-Software-From-DomainComputers.ps1](scripts/windows/inventory/Get-Software-From-DomainComputers.ps1) | Liest installierte Software (Registry-basiert, ohne Win32_Product) |
| [New-ComputerNameByMacAddress.ps1](scripts/windows/inventory/New-ComputerNameByMacAddress.ps1) | Ermittelt AABBCC aus PermanentAddress (alle Trennzeichen entfernt). Suffix "-M" wenn ein WLAN-Adapter gefunden wird, sonst "-D". Setzt MYCOMPUTERNAME in aktueller Session und, falls Adminrechte vorhanden, systemweit. |

## `scripts/windows/processes/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Get-Process-CPU-Usage-DomainWide.ps1](scripts/windows/processes/Get-Process-CPU-Usage-DomainWide.ps1) | _keine .SYNOPSIS_ |
| [log-start-stop-process.ps1](scripts/windows/processes/log-start-stop-process.ps1) | _keine .SYNOPSIS_ |
| [Remove-StuckProcess.ps1](scripts/windows/processes/Remove-StuckProcess.ps1) | _keine .SYNOPSIS_ |
| [Set-ProPriority.ps1](scripts/windows/processes/Set-ProPriority.ps1) | Setzt Prozesspriorität per Name oder PID Um es zu kompilieren, nutze PS2EXE: Install-Module PS2EXE -Scope CurrentUser Invoke-PS2EXE -inputFile "G:\AVERP\Set-ProcPriority.ps1" -outputFile "G:\AVERP\Set-ProcPriority.exe" -noConsole \\myserver\myshare\Set-ProcPriority.exe -Name MYPROCESS -Priority AboveNormal |

## `scripts/windows/registry/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Check-RemoteRegistry.ps1](scripts/windows/registry/Check-RemoteRegistry.ps1) | _keine .SYNOPSIS_ |
| [get-remote-registry-values.ps1](scripts/windows/registry/get-remote-registry-values.ps1) | _keine .SYNOPSIS_ |

## `scripts/windows/scheduled-tasks/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Export-Tasks.ps1](scripts/windows/scheduled-tasks/Export-Tasks.ps1) | _keine .SYNOPSIS_ |
| [Get-AllScheduledTasks.ps1](scripts/windows/scheduled-tasks/Get-AllScheduledTasks.ps1) | _keine .SYNOPSIS_ |

## `scripts/windows/services/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Check-ServiceOnMultipleClients.ps1](scripts/windows/services/Check-ServiceOnMultipleClients.ps1) | _keine .SYNOPSIS_ |
| [Get-TasksAndServices.ps1](scripts/windows/services/Get-TasksAndServices.ps1) | _keine .SYNOPSIS_ |
| [Set-ServiceStatupType.ps1](scripts/windows/services/Set-ServiceStatupType.ps1) | _keine .SYNOPSIS_ |

## `scripts/windows/sessions/`

| Skript | Beschreibung |
| ------ | ------------ |
| [check-inactive-idle-sessions.ps1](scripts/windows/sessions/check-inactive-idle-sessions.ps1) | _keine .SYNOPSIS_ |
| [Get-IdleTime-Single-User.ps1](scripts/windows/sessions/Get-IdleTime-Single-User.ps1) | _keine .SYNOPSIS_ |
| [Get-LastInteractiveUserLogons.ps1](scripts/windows/sessions/Get-LastInteractiveUserLogons.ps1) | _keine .SYNOPSIS_ |
| [Get-LoggedInUsers_CIMVariant.ps1](scripts/windows/sessions/Get-LoggedInUsers_CIMVariant.ps1) | _keine .SYNOPSIS_ |
| [Get-LoggedInUsers_InvokeCommandVariant.ps1](scripts/windows/sessions/Get-LoggedInUsers_InvokeCommandVariant.ps1) | _keine .SYNOPSIS_ |
| [get-UserSessionInfos__remove-UserSessions.ps1](scripts/windows/sessions/get-UserSessionInfos__remove-UserSessions.ps1) | _keine .SYNOPSIS_ |
| [Get-WorkstationUnlockEvents.ps1](scripts/windows/sessions/Get-WorkstationUnlockEvents.ps1) | _keine .SYNOPSIS_ |

## `scripts/windows/shadow-copy/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Create-ScheduledTasksWithXML.ps1](scripts/windows/shadow-copy/Create-ScheduledTasksWithXML.ps1) | _keine .SYNOPSIS_ |
| [Create-Spontaneous-Shadow-Copy.ps1](scripts/windows/shadow-copy/Create-Spontaneous-Shadow-Copy.ps1) | _keine .SYNOPSIS_ |
| [Enable-ShadowCopyC.ps1](scripts/windows/shadow-copy/Enable-ShadowCopyC.ps1) | _keine .SYNOPSIS_ |
| [test.ps1](scripts/windows/shadow-copy/test.ps1) | _keine .SYNOPSIS_ |

## `scripts/windows/telemetry/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Disable-Telemetry_v2.ps1](scripts/windows/telemetry/Disable-Telemetry_v2.ps1) | Deaktiviert systemweit Windows- und Office-Telemetrie |

## `scripts/windows/updates/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Get-InstalledUpdatesFromEventlog.ps1](scripts/windows/updates/Get-InstalledUpdatesFromEventlog.ps1) | _keine .SYNOPSIS_ |

## `scripts/windows/wmi/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Set-WbemTracing.ps1](scripts/windows/wmi/Set-WbemTracing.ps1) | _keine .SYNOPSIS_ |
| [WMIC-Wrapper.ps1](scripts/windows/wmi/WMIC-Wrapper.ps1) | Ruft WMI/CIM-Klasseninformationen effizient ab und stellt eine vereinfachte Schnittstelle bereit. |
| [wmirepair.ps1](scripts/windows/wmi/wmirepair.ps1) | Repariert beschädigte Windows Management Instrumentation (WMI) Repositories und Services. |

## `snippets/`

| Skript | Beschreibung |
| ------ | ------------ |
| [PSCustomObjectWithIndexColumn.ps1](snippets/PSCustomObjectWithIndexColumn.ps1) | _keine .SYNOPSIS_ |
| [Script-Block-Parameters.ps1](snippets/Script-Block-Parameters.ps1) | _keine .SYNOPSIS_ |

## `snippets/graph-traversal/`

| Skript | Beschreibung |
| ------ | ------------ |
| [BFS.ps1](snippets/graph-traversal/BFS.ps1) | _keine .SYNOPSIS_ |
| [Version-8.ps1](snippets/graph-traversal/Version-8.ps1) | _keine .SYNOPSIS_ |

## `tools/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Build-ScriptIndex.ps1](tools/Build-ScriptIndex.ps1) | Liest die .SYNOPSIS einer Datei ueber den AST, ohne sie auszufuehren. |

