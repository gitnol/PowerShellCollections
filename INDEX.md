# Skript-Index

<!-- Automatisch erzeugt von tools/Build-ScriptIndex.ps1 - nicht von Hand bearbeiten. -->

174 Skripte, davon 49 mit `.SYNOPSIS` (28%).

## `Active-Directory/`

| Skript | Beschreibung |
| ------ | ------------ |
| [_dump-ticketsize.1.7.ps1](Active-Directory/_dump-ticketsize.1.7.ps1) | _keine .SYNOPSIS_ |
| [_Get-TokenSizeReport.ps1](Active-Directory/_Get-TokenSizeReport.ps1) | _keine .SYNOPSIS_ |
| [AD-Computer-Inventory-Parallel.ps1](Active-Directory/AD-Computer-Inventory-Parallel.ps1) | Inventarisiert AD-Computer parallel und aktualisiert Benutzer-, Hardware- und Kommentar-Informationen im Description-Feld. |
| [bitlocker-status-de.ps1](Active-Directory/bitlocker-status-de.ps1) | _keine .SYNOPSIS_ |
| [bitlocker-status-en.ps1](Active-Directory/bitlocker-status-en.ps1) | _keine .SYNOPSIS_ |
| [Check-ADGroupIntegrity-Multi.ps1](Active-Directory/Check-ADGroupIntegrity-Multi.ps1) | _keine .SYNOPSIS_ |
| [Check-ADGroupIntegrity.ps1](Active-Directory/Check-ADGroupIntegrity.ps1) | Überwacht die Integrität einer AD-Gruppe für PRTG und setzt einen Alarm (Latch/Breach) bei Änderungen. |
| [check-for-bad-passwords.ps1](Active-Directory/check-for-bad-passwords.ps1) | _keine .SYNOPSIS_ |
| [compare-aduser-groups.ps1](Active-Directory/compare-aduser-groups.ps1) | _keine .SYNOPSIS_ |
| [Copy-ADGroupMember.ps1](Active-Directory/Copy-ADGroupMember.ps1) | _keine .SYNOPSIS_ |
| [Fileserver-Einzelberechtigungen-fuer-User.ps1](Active-Directory/Fileserver-Einzelberechtigungen-fuer-User.ps1) | _keine .SYNOPSIS_ |
| [Get-ADAuthEventsAllDCs.ps1](Active-Directory/Get-ADAuthEventsAllDCs.ps1) | Sammelt Anmelde-Events (fehlgeschlagen, Lockout, erfolgreich) von allen Domain Controllern inkl. Quell-IP. |
| [Get-ADComputerLastLogon.ps1](Active-Directory/Get-ADComputerLastLogon.ps1) | _keine .SYNOPSIS_ |
| [Get-ADUserLastLogonCache.ps1](Active-Directory/Get-ADUserLastLogonCache.ps1) | _keine .SYNOPSIS_ |
| [get-dhcpserver-leases_v2.ps1](Active-Directory/get-dhcpserver-leases_v2.ps1) | _keine .SYNOPSIS_ |
| [get-dhcpserver-leases.ps1](Active-Directory/get-dhcpserver-leases.ps1) | _keine .SYNOPSIS_ |
| [Get-DuplicateMachineSIDs.ps1](Active-Directory/Get-DuplicateMachineSIDs.ps1) | _keine .SYNOPSIS_ |
| [get-enabled_ad_user_with_managers.ps1](Active-Directory/get-enabled_ad_user_with_managers.ps1) | _keine .SYNOPSIS_ |
| [get-inactive-user-of-specific-group.ps1](Active-Directory/get-inactive-user-of-specific-group.ps1) | _keine .SYNOPSIS_ |
| [Get-LockedOutEventsAllDCs.ps1](Active-Directory/Get-LockedOutEventsAllDCs.ps1) | Sammelt Account-Lockout-Events von allen Domain Controllern in der Domäne. |
| [Get-LogonAttempts.ps1](Active-Directory/Get-LogonAttempts.ps1) | _keine .SYNOPSIS_ |
| [Get-RecursiveGroupSIDs-Vergleich-zu-Get-ADPrincipalGroupMembership.ps1](Active-Directory/Get-RecursiveGroupSIDs-Vergleich-zu-Get-ADPrincipalGroupMembership.ps1) | _keine .SYNOPSIS_ |
| [get-remote-registry-values.ps1](Active-Directory/get-remote-registry-values.ps1) | _keine .SYNOPSIS_ |
| [get-user-logons.ps1](Active-Directory/get-user-logons.ps1) | _keine .SYNOPSIS_ |
| [LDAPServer.ps1](Active-Directory/LDAPServer.ps1) | _keine .SYNOPSIS_ |
| [Protect-OUs.ps1](Active-Directory/Protect-OUs.ps1) | Aktiviert den Schutz vor versehentlichem Löschen für alle OUs in der Domäne. |
| [resolve-ad-groups-recursively.ps1](Active-Directory/resolve-ad-groups-recursively.ps1) | _keine .SYNOPSIS_ |
| [Set-UserPhotoHybrid.ps1](Active-Directory/Set-UserPhotoHybrid.ps1) | _keine .SYNOPSIS_ |
| [temporary-groupmembership_v2.ps1](Active-Directory/temporary-groupmembership_v2.ps1) | _keine .SYNOPSIS_ |
| [temporary-groupmembership.ps1](Active-Directory/temporary-groupmembership.ps1) | _keine .SYNOPSIS_ |
| [Test-DomainCredentials.ps1](Active-Directory/Test-DomainCredentials.ps1) | _keine .SYNOPSIS_ |
| [Test-LdapPorts.ps1](Active-Directory/Test-LdapPorts.ps1) | _keine .SYNOPSIS_ |

## `Active-Directory/DNS/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Find-DNSDuplicates.ps1](Active-Directory/DNS/Find-DNSDuplicates.ps1) | Findet und entfernt doppelte DNS-A-Einträge zonenübergreifend. |

## `Active-Directory/GPO/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Create-GPOAnalysis.ps1](Active-Directory/GPO/Create-GPOAnalysis.ps1) | _keine .SYNOPSIS_ |
| [Get-GPO_GPP_ItemLevelTargeting.ps1](Active-Directory/GPO/Get-GPO_GPP_ItemLevelTargeting.ps1) | _keine .SYNOPSIS_ |
| [Get-GPOLinks.ps1](Active-Directory/GPO/Get-GPOLinks.ps1) | _keine .SYNOPSIS_ |
| [Get-GPOReportSettings.ps1](Active-Directory/GPO/Get-GPOReportSettings.ps1) | _keine .SYNOPSIS_ |

## `Active-Directory/PDCEmulator_manual_TimeSettings/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Set-TimeSync.ps1](Active-Directory/PDCEmulator_manual_TimeSettings/Set-TimeSync.ps1) | Konfiguriert die Zeitsynchronisierung für den PDC-Emulationsmaster korrekt. Besser ist es jedoch, wenn eine GPO für die Zeitsynchronisierung verwendet wird. |

## `Active-Directory/Temporäre-Gruppenmitgliedschaften-Verwalten/`

| Skript | Beschreibung |
| ------ | ------------ |
| [temp_gruppenmitgliedschaft_bearbeiten_v2.ps1](Active-Directory/Temporäre-Gruppenmitgliedschaften-Verwalten/temp_gruppenmitgliedschaft_bearbeiten_v2.ps1) | Automatisiert temporäre Active Directory-Gruppenmitgliedschaften für Auszubildende und andere Benutzer basierend auf Abteilungszuordnungen. |
| [temp_gruppenmitgliedschaft_bearbeiten_v3.ps1](Active-Directory/Temporäre-Gruppenmitgliedschaften-Verwalten/temp_gruppenmitgliedschaft_bearbeiten_v3.ps1) | Automatisiert temporäre und permanente Active Directory-Gruppenmitgliedschaften basierend auf CSV-Dateien. |

## `Aruba/`

| Skript | Beschreibung |
| ------ | ------------ |
| [aruba.ps1](Aruba/aruba.ps1) | _keine .SYNOPSIS_ |
| [aruba1.ps1](Aruba/aruba1.ps1) | _keine .SYNOPSIS_ |

## `Certificates/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Generate-Certificate.ps1](Certificates/Generate-Certificate.ps1) | _keine .SYNOPSIS_ |
| [Replace-VMWare-Certificates.ps1](Certificates/Replace-VMWare-Certificates.ps1) | _keine .SYNOPSIS_ |
| [Request-Certificate.ps1](Certificates/Request-Certificate.ps1) | Requests a certificate from a Windows CA |

## `DocuWare/`

| Skript | Beschreibung |
| ------ | ------------ |
| [IIS-Analyse-DocuWare.ps1](DocuWare/IIS-Analyse-DocuWare.ps1) | Gibt alle IIS-Logzeilen der letzten X Minuten als PSCustomObject zurück (alle Felder). |

## `Exchange_Outlook/Exchange/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Get-MailBoxForwardingRules.ps1](Exchange_Outlook/Exchange/Get-MailBoxForwardingRules.ps1) | _keine .SYNOPSIS_ |
| [Manage-SharedMailboxPermissions.ps1](Exchange_Outlook/Exchange/Manage-SharedMailboxPermissions.ps1) | _keine .SYNOPSIS_ |
| [New-SharedMailboxWorkflow.ps1](Exchange_Outlook/Exchange/New-SharedMailboxWorkflow.ps1) | _keine .SYNOPSIS_ |

## `Exchange_Outlook/Outlook/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Manage-OutlookAddins.ps1](Exchange_Outlook/Outlook/Manage-OutlookAddins.ps1) | Verwaltet Outlook Add-ins (Status prüfen, Listen, Reparieren). |

## `Knowledge-Codesamples/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Script-Block-Parameters.ps1](Knowledge-Codesamples/Script-Block-Parameters.ps1) | _keine .SYNOPSIS_ |

## `LANCOM/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Create-PublicSpotUsers_old.ps1](LANCOM/Create-PublicSpotUsers_old.ps1) | Erstellt Public Spot Benutzer für LANCOM WLC/Router in Massenverarbeitung basierend auf einer CSV-Datei. |
| [Create-PublicSpotUsers.ps1](LANCOM/Create-PublicSpotUsers.ps1) | Erstellt Public Spot Benutzer für LANCOM WLC/Router in Massenverarbeitung basierend auf einer CSV-Datei. |
| [New-PublicSpotUser.ps1](LANCOM/New-PublicSpotUser.ps1) | Registers a new Public Spot user via a REST API call to a specified server. |

## `LOST+FOUND+UNTESTED/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Suche_nach_log4j_Dateien_optimiert.ps1](LOST+FOUND+UNTESTED/Suche_nach_log4j_Dateien_optimiert.ps1) | _keine .SYNOPSIS_ |
| [Suche_nach_log4j_Dateien.ps1](LOST+FOUND+UNTESTED/Suche_nach_log4j_Dateien.ps1) | _keine .SYNOPSIS_ |

## `MSSQL-Server/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Check-DbConnection.ps1](MSSQL-Server/Check-DbConnection.ps1) | Prüft eine OLE DB Datenbankverbindung mit interaktiver Passwortabfrage. |
| [Get-SqlServerVersion.ps1](MSSQL-Server/Get-SqlServerVersion.ps1) | Ermittelt die Versionen von SQL Server Instanzen auf remote Servern. |

## `OpenScapeBusinessAPIWrapper/`

| Skript | Beschreibung |
| ------ | ------------ |
| [OZBiz-Functions.psm1](OpenScapeBusinessAPIWrapper/OZBiz-Functions.psm1) | Meldet sich an der OSBiz API an und gibt die Session-ID zurück. |

## `PSMailstore/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Mailstore-Scripts.ps1](PSMailstore/Mailstore-Scripts.ps1) | _keine .SYNOPSIS_ |
| [Mailstore-Scripts2.ps1](PSMailstore/Mailstore-Scripts2.ps1) | _keine .SYNOPSIS_ |
| [MailStoreFunctionsFromAPI.ps1](PSMailstore/MailStoreFunctionsFromAPI.ps1) | _keine .SYNOPSIS_ |

## `PSMailstore/API-Wrapper/`

| Skript | Beschreibung |
| ------ | ------------ |
| [MS.PS.Lib.psm1](PSMailstore/API-Wrapper/MS.PS.Lib.psm1) | _keine .SYNOPSIS_ |

## `PSMailstore/Scripts/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Example1.ps1](PSMailstore/Scripts/Example1.ps1) | _keine .SYNOPSIS_ |
| [Example2.ps1](PSMailstore/Scripts/Example2.ps1) | _keine .SYNOPSIS_ |
| [Example3.ps1](PSMailstore/Scripts/Example3.ps1) | _keine .SYNOPSIS_ |
| [Example4.ps1](PSMailstore/Scripts/Example4.ps1) | _keine .SYNOPSIS_ |

## `scripts/monitoring/prtg/dsls/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Get-DslsLicenseUsage.ps1](scripts/monitoring/prtg/dsls/Get-DslsLicenseUsage.ps1) | PRTG-Sensor: Lizenznutzung und Restlaufzeit je Komponente auf dem DSLS. |
| [Get-DslsLogError.ps1](scripts/monitoring/prtg/dsls/Get-DslsLogError.ps1) | PRTG-Sensor: Anzahl der Fehlermeldungen im DSLS-Log der letzten 24 Stunden. |
| [Get-DslsOfflineLicense.ps1](scripts/monitoring/prtg/dsls/Get-DslsOfflineLicense.ps1) | PRTG-Sensor: Anzahl der aktuell vergebenen Offline-Lizenzen (Nomad) auf dem DSLS. |
| [PRTG.Dsls.psm1](scripts/monitoring/prtg/dsls/PRTG.Dsls.psm1) | Gemeinsame Hilfsfunktionen fuer die DSLS-Sensoren (Dassault Systemes License Server). |

## `Server-Client-Helper-Stuff/`

| Skript | Beschreibung |
| ------ | ------------ |
| [check-inactive-idle-sessions.ps1](Server-Client-Helper-Stuff/check-inactive-idle-sessions.ps1) | _keine .SYNOPSIS_ |
| [Check-MachineSID.ps1](Server-Client-Helper-Stuff/Check-MachineSID.ps1) | Prüft den Online-Status von AD-Computern und führt optional einen Neustart oder eine SID-Prüfung durch. |
| [Check-RemoteRegistry.ps1](Server-Client-Helper-Stuff/Check-RemoteRegistry.ps1) | _keine .SYNOPSIS_ |
| [Check-ServiceOnMultipleClients.ps1](Server-Client-Helper-Stuff/Check-ServiceOnMultipleClients.ps1) | _keine .SYNOPSIS_ |
| [Cleanup-Firewall-Rules.ps1](Server-Client-Helper-Stuff/Cleanup-Firewall-Rules.ps1) | _keine .SYNOPSIS_ |
| [Clear-OldTempFiles_v2.ps1](Server-Client-Helper-Stuff/Clear-OldTempFiles_v2.ps1) | Erweiterte Windows-Bereinigung für temporäre Dateien und Cache-Verzeichnisse |
| [Clear-OldTempFiles_v3.ps1](Server-Client-Helper-Stuff/Clear-OldTempFiles_v3.ps1) | Erweiterte Windows-Bereinigung für temporäre Dateien und Cache-Verzeichnisse |
| [Clear-OldTempFiles_v4.ps1](Server-Client-Helper-Stuff/Clear-OldTempFiles_v4.ps1) | Ultimate Windows Cleanup Tool v4.0 (Fixed) - Stabile Version |
| [Clear-OldTempFiles.ps1](Server-Client-Helper-Stuff/Clear-OldTempFiles.ps1) | Gibt eine Liste bereinigungswürdiger Verzeichnispfade zurück. Bezieht sowohl systemweite als auch benutzerspezifische Pfade ein. |
| [Elevate.ps1](Server-Client-Helper-Stuff/Elevate.ps1) | _keine .SYNOPSIS_ |
| [Elevate(Old).ps1](Server-Client-Helper-Stuff/Elevate(Old).ps1) | _keine .SYNOPSIS_ |
| [Export-Tasks.ps1](Server-Client-Helper-Stuff/Export-Tasks.ps1) | _keine .SYNOPSIS_ |
| [Get-AllScheduledTasks.ps1](Server-Client-Helper-Stuff/Get-AllScheduledTasks.ps1) | _keine .SYNOPSIS_ |
| [Get-ClientMonitorEDIDData.ps1](Server-Client-Helper-Stuff/Get-ClientMonitorEDIDData.ps1) | _keine .SYNOPSIS_ |
| [Get-ComputerOnlineStatus_Alternative.ps1](Server-Client-Helper-Stuff/Get-ComputerOnlineStatus_Alternative.ps1) | Prüft den Online-Status von Computern aus Active Directory und listet deren IP-Adressen auf. |
| [Get-ComputerOnlineStatus.ps1](Server-Client-Helper-Stuff/Get-ComputerOnlineStatus.ps1) | _keine .SYNOPSIS_ |
| [Get-IdleTime-Single-User.ps1](Server-Client-Helper-Stuff/Get-IdleTime-Single-User.ps1) | _keine .SYNOPSIS_ |
| [Get-InstalledUpdatesFromEventlog.ps1](Server-Client-Helper-Stuff/Get-InstalledUpdatesFromEventlog.ps1) | _keine .SYNOPSIS_ |
| [Get-LastInteractiveUserLogons.ps1](Server-Client-Helper-Stuff/Get-LastInteractiveUserLogons.ps1) | _keine .SYNOPSIS_ |
| [Get-LoggedInUsers_CIMVariant.ps1](Server-Client-Helper-Stuff/Get-LoggedInUsers_CIMVariant.ps1) | _keine .SYNOPSIS_ |
| [Get-LoggedInUsers_InvokeCommandVariant.ps1](Server-Client-Helper-Stuff/Get-LoggedInUsers_InvokeCommandVariant.ps1) | _keine .SYNOPSIS_ |
| [Get-Process-CPU-Usage-DomainWide.ps1](Server-Client-Helper-Stuff/Get-Process-CPU-Usage-DomainWide.ps1) | _keine .SYNOPSIS_ |
| [Get-TasksAndServices.ps1](Server-Client-Helper-Stuff/Get-TasksAndServices.ps1) | _keine .SYNOPSIS_ |
| [Get-TextMatchInFiles.ps1](Server-Client-Helper-Stuff/Get-TextMatchInFiles.ps1) | _keine .SYNOPSIS_ |
| [get-UserSessionInfos__remove-UserSessions.ps1](Server-Client-Helper-Stuff/get-UserSessionInfos__remove-UserSessions.ps1) | _keine .SYNOPSIS_ |
| [Get-WorkstationUnlockEvents.ps1](Server-Client-Helper-Stuff/Get-WorkstationUnlockEvents.ps1) | _keine .SYNOPSIS_ |
| [log-start-stop-process.ps1](Server-Client-Helper-Stuff/log-start-stop-process.ps1) | _keine .SYNOPSIS_ |
| [remove-old-user-profiles.ps1](Server-Client-Helper-Stuff/remove-old-user-profiles.ps1) | _keine .SYNOPSIS_ |
| [Remove-StuckProcess.ps1](Server-Client-Helper-Stuff/Remove-StuckProcess.ps1) | _keine .SYNOPSIS_ |
| [Resolve-Links.ps1](Server-Client-Helper-Stuff/Resolve-Links.ps1) | _keine .SYNOPSIS_ |
| [Set-ProPriority.ps1](Server-Client-Helper-Stuff/Set-ProPriority.ps1) | Setzt Prozesspriorität per Name oder PID Um es zu kompilieren, nutze PS2EXE: Install-Module PS2EXE -Scope CurrentUser Invoke-PS2EXE -inputFile "G:\AVERP\Set-ProcPriority.ps1" -outputFile "G:\AVERP\Set-ProcPriority.exe" -noConsole \\myserver\myshare\Set-ProcPriority.exe -Name MYPROCESS -Priority AboveNormal |
| [Set-ServiceStatupType.ps1](Server-Client-Helper-Stuff/Set-ServiceStatupType.ps1) | _keine .SYNOPSIS_ |
| [WMIC-Wrapper.ps1](Server-Client-Helper-Stuff/WMIC-Wrapper.ps1) | Ruft WMI/CIM-Klasseninformationen effizient ab und stellt eine vereinfachte Schnittstelle bereit. |

## `Server-Client-Helper-Stuff/EnableShadowCopy/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Create-ScheduledTasksWithXML.ps1](Server-Client-Helper-Stuff/EnableShadowCopy/Create-ScheduledTasksWithXML.ps1) | _keine .SYNOPSIS_ |
| [Create-Spontaneous-Shadow-Copy.ps1](Server-Client-Helper-Stuff/EnableShadowCopy/Create-Spontaneous-Shadow-Copy.ps1) | _keine .SYNOPSIS_ |
| [Enable-ShadowCopyC.ps1](Server-Client-Helper-Stuff/EnableShadowCopy/Enable-ShadowCopyC.ps1) | _keine .SYNOPSIS_ |
| [test.ps1](Server-Client-Helper-Stuff/EnableShadowCopy/test.ps1) | _keine .SYNOPSIS_ |

## `Server-Client-Helper-Stuff/Network/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Show-NetConnections.ps1](Server-Client-Helper-Stuff/Network/Show-NetConnections.ps1) | Zeigt aktive TCP/UDP-Verbindungen inkl. Prozessinformationen, ähnlich netstat -anob. |

## `Server-Client-Helper-Stuff/PCActivityTimeline/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Get-PCActivityTimeline.ps1](Server-Client-Helper-Stuff/PCActivityTimeline/Get-PCActivityTimeline.ps1) | _keine .SYNOPSIS_ |
| [Test-PCActivityTimeline.ps1](Server-Client-Helper-Stuff/PCActivityTimeline/Test-PCActivityTimeline.ps1) | _keine .SYNOPSIS_ |

## `Server-Client-Helper-Stuff/SecureBoot/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Check-MultipleHostsSecureBoot.ps1](Server-Client-Helper-Stuff/SecureBoot/Check-MultipleHostsSecureBoot.ps1) | _keine .SYNOPSIS_ |
| [Invoke-SecureBootCertUpdate_simple.ps1](Server-Client-Helper-Stuff/SecureBoot/Invoke-SecureBootCertUpdate_simple.ps1) | _keine .SYNOPSIS_ |
| [Invoke-SecureBootCertUpdate.ps1](Server-Client-Helper-Stuff/SecureBoot/Invoke-SecureBootCertUpdate.ps1) | _keine .SYNOPSIS_ |
| [Test-MultipleHostsSecureBoot.ps1](Server-Client-Helper-Stuff/SecureBoot/Test-MultipleHostsSecureBoot.ps1) | _keine .SYNOPSIS_ |
| [Test-SecureBootCert2023.ps1](Server-Client-Helper-Stuff/SecureBoot/Test-SecureBootCert2023.ps1) | _keine .SYNOPSIS_ |

## `Server-Client-Helper-Stuff/SecureBoot/Check-UEFISecureBootVariables-main/ps/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Check SVN history.ps1](Server-Client-Helper-Stuff/SecureBoot/Check-UEFISecureBootVariables-main/ps/Check SVN history.ps1) | _keine .SYNOPSIS_ |
| [Check UEFI PK, KEK, DB and DBX.ps1](Server-Client-Helper-Stuff/SecureBoot/Check-UEFISecureBootVariables-main/ps/Check UEFI PK, KEK, DB and DBX.ps1) | _keine .SYNOPSIS_ |
| [Check Windows state.ps1](Server-Client-Helper-Stuff/SecureBoot/Check-UEFISecureBootVariables-main/ps/Check Windows state.ps1) | _keine .SYNOPSIS_ |
| [Check-Dbx-Simplified.ps1](Server-Client-Helper-Stuff/SecureBoot/Check-UEFISecureBootVariables-main/ps/Check-Dbx-Simplified.ps1) | _keine .SYNOPSIS_ |
| [Dump-SecureBootData.ps1](Server-Client-Helper-Stuff/SecureBoot/Check-UEFISecureBootVariables-main/ps/Dump-SecureBootData.ps1) | _keine .SYNOPSIS_ |
| [Find-EfiFilesRevokedByDbx.ps1](Server-Client-Helper-Stuff/SecureBoot/Check-UEFISecureBootVariables-main/ps/Find-EfiFilesRevokedByDbx.ps1) | _keine .SYNOPSIS_ |
| [Get-BootMgrSecurityVersion.psm1](Server-Client-Helper-Stuff/SecureBoot/Check-UEFISecureBootVariables-main/ps/Get-BootMgrSecurityVersion.psm1) | _keine .SYNOPSIS_ |
| [Get-EfiSignatures.psm1](Server-Client-Helper-Stuff/SecureBoot/Check-UEFISecureBootVariables-main/ps/Get-EfiSignatures.psm1) | _keine .SYNOPSIS_ |
| [Get-PEInfo.psm1](Server-Client-Helper-Stuff/SecureBoot/Check-UEFISecureBootVariables-main/ps/Get-PEInfo.psm1) | _keine .SYNOPSIS_ |
| [Get-SBAT.psm1](Server-Client-Helper-Stuff/SecureBoot/Check-UEFISecureBootVariables-main/ps/Get-SBAT.psm1) | _keine .SYNOPSIS_ |
| [Get-SVNfromDBX.psm1](Server-Client-Helper-Stuff/SecureBoot/Check-UEFISecureBootVariables-main/ps/Get-SVNfromDBX.psm1) | _keine .SYNOPSIS_ |
| [Get-UEFIDatabaseSignatures.psm1](Server-Client-Helper-Stuff/SecureBoot/Check-UEFISecureBootVariables-main/ps/Get-UEFIDatabaseSignatures.psm1) | Parses UEFI Signature Databases into logical Powershell objects |

## `Server-Client-Helper-Stuff/Telemetry/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Disable-Telemetry_v2.ps1](Server-Client-Helper-Stuff/Telemetry/Disable-Telemetry_v2.ps1) | Deaktiviert systemweit Windows- und Office-Telemetrie |

## `Server-Client-Helper-Stuff/Wake-On-Lan/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Set-WakeOnLAN-AdapterOptions.ps1](Server-Client-Helper-Stuff/Wake-On-Lan/Set-WakeOnLAN-AdapterOptions.ps1) | _keine .SYNOPSIS_ |
| [Wake-On-Lan.ps1](Server-Client-Helper-Stuff/Wake-On-Lan/Wake-On-Lan.ps1) | Sendet ein Wake-on-LAN Magic Packet an eine MAC-Adresse. |

## `Server-Client-Helper-Stuff/WMIRepair/`

| Skript | Beschreibung |
| ------ | ------------ |
| [wmirepair.ps1](Server-Client-Helper-Stuff/WMIRepair/wmirepair.ps1) | Repariert beschädigte Windows Management Instrumentation (WMI) Repositories und Services. |

## `Server-Client-Helper-Stuff/ZIP-Utilities/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Find-FilesInZips.ps1](Server-Client-Helper-Stuff/ZIP-Utilities/Find-FilesInZips.ps1) | Durchsucht ZIP-Archive nach Dateien basierend auf einem Suchmuster. |

## `tools/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Build-ScriptIndex.ps1](tools/Build-ScriptIndex.ps1) | Liest die .SYNOPSIS einer Datei ueber den AST, ohne sie auszufuehren. |

## `unsorted-stuff/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Compress-FilesByMonth.ps1](unsorted-stuff/Compress-FilesByMonth.ps1) | _keine .SYNOPSIS_ |
| [Get-DLLVersion.ps1](unsorted-stuff/Get-DLLVersion.ps1) | _keine .SYNOPSIS_ |
| [Get-FolderPermissions.ps1](unsorted-stuff/Get-FolderPermissions.ps1) | _keine .SYNOPSIS_ |
| [Get-MailStore-API-Function-Reference.ps1](unsorted-stuff/Get-MailStore-API-Function-Reference.ps1) | _keine .SYNOPSIS_ |
| [Get-Software-From-DomainComputers.ps1](unsorted-stuff/Get-Software-From-DomainComputers.ps1) | Liest installierte Software (Registry-basiert, ohne Win32_Product) |
| [New-ComputerNameByMacAddress.ps1](unsorted-stuff/New-ComputerNameByMacAddress.ps1) | Ermittelt AABBCC aus PermanentAddress (alle Trennzeichen entfernt). Suffix "-M" wenn ein WLAN-Adapter gefunden wird, sonst "-D". Setzt MYCOMPUTERNAME in aktueller Session und, falls Adminrechte vorhanden, systemweit. |
| [PSCustomObjectWithIndexColumn.ps1](unsorted-stuff/PSCustomObjectWithIndexColumn.ps1) | _keine .SYNOPSIS_ |
| [test-port.ps1](unsorted-stuff/test-port.ps1) | _keine .SYNOPSIS_ |
| [test.ps1](unsorted-stuff/test.ps1) | _keine .SYNOPSIS_ _(Achtung: 6 Parserfehler)_ |

## `unsorted-stuff/BFS_and_DFS/`

| Skript | Beschreibung |
| ------ | ------------ |
| [BFS.ps1](unsorted-stuff/BFS_and_DFS/BFS.ps1) | _keine .SYNOPSIS_ |
| [Version-8.ps1](unsorted-stuff/BFS_and_DFS/Version-8.ps1) | _keine .SYNOPSIS_ |

## `unsorted-stuff/ClientInfos/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Get-DiskInformation.ps1](unsorted-stuff/ClientInfos/Get-DiskInformation.ps1) | _keine .SYNOPSIS_ |

## `unsorted-stuff/CS/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Install-FalconSensor.ps1](unsorted-stuff/CS/Install-FalconSensor.ps1) | Kopiert eine Installationsdatei (z.B. FalconSensor) auf Zielcomputer und führt sie dort remote mit Parametern aus. Das Skript muss als Administrator ausgeführt werden. |

## `unsorted-stuff/EventLogs/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Clear-Eventlog.ps1](unsorted-stuff/EventLogs/Clear-Eventlog.ps1) | _keine .SYNOPSIS_ |
| [Setup-EventLog.ps1](unsorted-stuff/EventLogs/Setup-EventLog.ps1) | Erstellt die Event Log-Quelle für ProcessMonitorService |
| [Simple-EventLog-Setup.ps1](unsorted-stuff/EventLogs/Simple-EventLog-Setup.ps1) | _keine .SYNOPSIS_ |

## `unsorted-stuff/Excel/`

| Skript | Beschreibung |
| ------ | ------------ |
| [excel-to-pscustomobject.ps1](unsorted-stuff/Excel/excel-to-pscustomobject.ps1) | _keine .SYNOPSIS_ |
| [Remove-ExcelSheetProtection_v4.ps1](unsorted-stuff/Excel/Remove-ExcelSheetProtection_v4.ps1) | Entfernt den Blattschutz (Worksheet Protection) aus einer oder mehreren Tabellen einer .xlsx-Datei durch direkte XML-Manipulation. |

## `unsorted-stuff/Fenster_überlappen/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Set-ForegroundWindows_v2.ps1](unsorted-stuff/Fenster_überlappen/Set-ForegroundWindows_v2.ps1) | Skript zur Wiederherstellung der "Fenster überlappend anzeigen"-Funktion unter Windows 11. |
| [Set-ForegroundWindows.ps1](unsorted-stuff/Fenster_überlappen/Set-ForegroundWindows.ps1) | Skript zur Wiederherstellung der "Fenster überlappend anzeigen"-Funktion unter Windows 11. |

## `unsorted-stuff/FileZilla/`

| Skript | Beschreibung |
| ------ | ------------ |
| [FileZilla.ps1](unsorted-stuff/FileZilla/FileZilla.ps1) | _keine .SYNOPSIS_ |
| [Get-FtpLoginSummary.ps1](unsorted-stuff/FileZilla/Get-FtpLoginSummary.ps1) | _keine .SYNOPSIS_ |

## `unsorted-stuff/Microsoft_Teams/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Clear-TeamsCache.ps1](unsorted-stuff/Microsoft_Teams/Clear-TeamsCache.ps1) | _keine .SYNOPSIS_ |

## `unsorted-stuff/NoSpamProxy/`

| Skript | Beschreibung |
| ------ | ------------ |
| [user-to-domain-communication.ps1](unsorted-stuff/NoSpamProxy/user-to-domain-communication.ps1) | _keine .SYNOPSIS_ |

## `unsorted-stuff/playground/`

| Skript | Beschreibung |
| ------ | ------------ |
| [New-ADGroupInOU_with_some_stuff.ps1](unsorted-stuff/playground/New-ADGroupInOU_with_some_stuff.ps1) | _keine .SYNOPSIS_ |

## `unsorted-stuff/SysinternalsSuite/`

| Skript | Beschreibung |
| ------ | ------------ |
| [autoruns2pwsh.ps1](unsorted-stuff/SysinternalsSuite/autoruns2pwsh.ps1) | PowerShell script to manage Windows startup entries using Sysinternals Autoruns |

## `unsorted-stuff/TeamViewer/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Parse-TeamViewerLogFile.ps1](unsorted-stuff/TeamViewer/Parse-TeamViewerLogFile.ps1) | _keine .SYNOPSIS_ |
| [Set-TeamViewerAccess.ps1](unsorted-stuff/TeamViewer/Set-TeamViewerAccess.ps1) | _keine .SYNOPSIS_ |
| [TeamViewer-Wrapper.ps1](unsorted-stuff/TeamViewer/TeamViewer-Wrapper.ps1) | Startet TeamViewer mit verschiedenen Konfigurationsoptionen und Verbindungsparametern. |

## `unsorted-stuff/WBEM/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Set-WbemTracing.ps1](unsorted-stuff/WBEM/Set-WbemTracing.ps1) | _keine .SYNOPSIS_ |

## `unsorted-stuff/WebChanges/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Monitor-Webchanges.ps1](unsorted-stuff/WebChanges/Monitor-Webchanges.ps1) | _keine .SYNOPSIS_ |

## `unsorted-stuff/Windows10Monitor/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Start-Win10PingMonitor.ps1](unsorted-stuff/Windows10Monitor/Start-Win10PingMonitor.ps1) | _keine .SYNOPSIS_ |
| [Win10PingMonitor.psm1](unsorted-stuff/Windows10Monitor/Win10PingMonitor.psm1) | Schreibt Meldungen in eine Log-Datei |

## `VMware/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Create-Windows-VM-vSphere-Template.ps1](VMware/Create-Windows-VM-vSphere-Template.ps1) | Bereitet eine Windows-VM als vSphere-Template vor. |
| [Get-VMSnapshots.ps1](VMware/Get-VMSnapshots.ps1) | _keine .SYNOPSIS_ |
| [Get-VMUptimes.ps1](VMware/Get-VMUptimes.ps1) | _keine .SYNOPSIS_ |

## `WebServer/`

| Skript | Beschreibung |
| ------ | ------------ |
| [Get-WebHeaders.ps1](WebServer/Get-WebHeaders.ps1) | Liest HTTP Response-Header und Statuscode aus. |

## `Zammad/`

| Skript | Beschreibung |
| ------ | ------------ |
| [MoreAPITests.ps1](Zammad/MoreAPITests.ps1) | _keine .SYNOPSIS_ |
| [OnceMoreAPITests.ps1](Zammad/OnceMoreAPITests.ps1) | _keine .SYNOPSIS_ |
| [SomeAPITests.ps1](Zammad/SomeAPITests.ps1) | _keine .SYNOPSIS_ |

