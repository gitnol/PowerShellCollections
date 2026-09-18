# Functions Overview

| Funktionsname                    | Synopsis                                                                                                  |
| -------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `Invoke-OSBizMkCall`             | Startet einen Anruf asynchron, Antwort erfolgt sofort, Ergebnis kommt über Event-Kanal.                   |
| `Invoke-OSBizConsultationCall`   | Führt ein Beratungsgespräch (Consultation Call) während eines aktiven Gesprächs mit einer dritten Nummer. |
| `Invoke-OSBizAlternateCall`      | Wechselt zwischen gehaltenem und aktivem Gespräch.                                                        |
| `Invoke-OSBizReconnectCall`      | Stellt Verbindung zum gehaltenen Teilnehmer nach einem Beratungsgespräch wieder her.                      |
| `Invoke-OSBizConferenceCall`     | Startet eine Dreierkonferenz zwischen aktivem und gehaltenem Gespräch.                                    |
| `Invoke-OSBizEndConference`      | Beendet eine Dreierkonferenz (nur vom Konferenz-Master möglich).                                          |
| `Invoke-OSBizTransferCall`       | Führt eine Blind-Weiterleitung (Single Step Transfer) zu einem Zielgerät aus.                             |
| `Invoke-OSBizAttendedTransfer`   | Führt eine betreute Weiterleitung (Attended Transfer) zwischen aktivem und gehaltenem Gespräch aus.       |
| `Invoke-OSBizGetServerParam`     | Liest Systemwählparameter (Vorwahlen etc.) vom Server.                                                    |
| `Invoke-OSBizClearDisplay`       | Löscht angezeigten Text auf einem Gerätedisplay, der über API gesetzt wurde.                              |
| `Invoke-OSBizSetDisplay`         | Setzt statischen Text auf dem Gerätedisplay.                                                              |
| `Invoke-OSBizGetDoNotDisturb`    | Liest aktuellen "Nicht stören"-Status eines Geräts (veraltet, nur für Altkompatibilität).                 |
| `Invoke-OSBizGetForwarding`      | Liest aktuelle Anrufweiterleitung eines Geräts (veraltet, nur für Altkompatibilität).                     |
| `Invoke-OSBizGetEvents`          | Ruft Ereignisse (z. B. HookState, Presence) für ein Gerät vom Server ab.                                  |
| `Invoke-OSBizEventStart`         | Startet Event-Monitoring für ein Gerät.                                                                   |
| `Invoke-OSBizEventStop`          | Stoppt Event-Monitoring für ein Gerät.                                                                    |
| `Invoke-OSBizSetPresence`        | Setzt den Präsenzstatus eines Benutzers.                                                                  |
| `Invoke-OSBizSetCallMe`          | Aktiviert "Call Me"-Funktion für einen Benutzer.                                                          |
| `Invoke-OSBizGetPresenceXML`     | Ruft Präsenzstatus als XML ab.                                                                            |
| `Invoke-OSBizPresenceDBGet`      | Liest Einträge aus der Präsenzdatenbank.                                                                  |
| `Invoke-OSBizPresenceDBSet`      | Schreibt Einträge in die Präsenzdatenbank.                                                                |
| `Invoke-OSBizJournalRead`        | Liest Einträge aus dem Anrufjournal.                                                                      |
| `Invoke-OSBizJournalGroupByDate` | Liest Journal-Einträge gruppiert nach Datum.                                                              |
| `Invoke-OSBizJournalFetch`       | Ruft Journal-Einträge anhand einer ID oder Kriterien ab.                                                  |
| `Invoke-OSBizPhBookSearch`       | Sucht im Telefonbuch nach Einträgen.                                                                      |
| `Invoke-OSBizPhBookDetail`       | Liest Detailinformationen zu einem Telefonbucheintrag.                                                    |
| `Invoke-OSBizPhBookLookup`       | Führt eine Rückwärtssuche im Telefonbuch durch (z. B. Nummer → Name).                                     |

# Example Usage:

```powershell
Import-Module "path-to-file\OSBiz-WSI.psm1"
$base = "https://10.1.2.3:8802"
$login = Invoke-OSBizLogin -BaseUrl $base -User 123 -Pass 123456
Invoke-OSBizMakeCall -BaseUrl $base -SessionID $login.SessionID -CallingDevice 123 -CalledDirectoryNumber 456
Invoke-OSBizLogout -BaseUrl $base -SessionID $login.SessionID
```