#Requires -Version 7.0
<#
.SYNOPSIS
    Ermittelt AD-Gruppen, die auf ALLEN Objekten unterhalb eines Basisverzeichnisses Lesezugriff haben.

.DESCRIPTION
    Das Skript durchläuft ab -Path die komplette Ordner-/Dateistruktur (NTFS) und wertet die DACL jedes
    Objekts aus. Identische ACLs (gleicher SDDL-String) werden nur EINMAL ausgewertet; für jedes Objekt wird
    lediglich ein Zähler erhöht. Dadurch bleibt der Aufwand auch bei Millionen Objekten überschaubar.

    Je Sicherheitsprinzipal (SID) wird ermittelt, auf wie vielen Objekten effektiv ReadData-Recht besteht
    (Allow-ACEs abzüglich Deny-ACEs derselben SID, reine InheritOnly-ACEs zählen für das Objekt nicht).
    Anschließend werden die SIDs per AD aufgelöst (mit Cache). Ausgegeben werden nur Gruppen.

    Ergebnis:
      - Gruppen mit 100 % Abdeckung ("Vollständig") -> haben auf jedem Objekt Lesezugriff.
      - Gibt es keine, werden die besten Kandidaten mit Abdeckungsgrad und Ausnahmepfaden ausgegeben.

    Optional (am Ende des Laufs):
      -MinimalGroupSet : kleinste Gruppenauswahl, die zusammen möglichst viel Lesezugriff ergibt
                         (Set-Cover: Greedy mit Deny-Berücksichtigung + Redundanzbereinigung).
      -ResolveUsers    : Benutzer, die über alle ihre Gruppen zusammen (inkl. Verschachtelung, Deny und
                         lokaler Administratorengruppe) auf alles Lesezugriff haben.

    Stufe je Gruppe: höchste/niedrigste Zugriffsstufe über alle Objekte mit Lesezugriff
    (Read, ReadAndExecute, Modify, FullControl). "NurLesend" = auf keinem Objekt Schreib-/Lösch-/Rechte-Bits.

.PARAMETER Path
    Basisverzeichnis (lokaler Pfad oder UNC). Das Basisverzeichnis selbst wird mitgeprüft.

.PARAMETER Depth
    Maximale Tiefe unterhalb des Basisverzeichnisses (0 = nur Basisordner und dessen Dateien,
    1 = zusätzlich direkte Unterordner usw.). Standard -1 = unbegrenzt.

.PARAMETER FoldersOnly
    Nur Ordner prüfen, Dateien überspringen (deutlich schneller, aber Dateien mit unterbrochener
    Vererbung werden dann nicht erkannt). Standard: Ordner UND Dateien.

.PARAMETER IncludeBuiltIn
    Well-known SIDs (SYSTEM, Administratoren, Authenticated Users ...) sowie nicht in AD auflösbare SIDs
    (lokale Konten, verwaiste SIDs) mit ausgeben. Standard: ausblenden.

.PARAMETER ExcludeGroupName
    Gruppennamen (Wildcards erlaubt, z. B. 'Domain Admins', 'GG_IT_*), die aus dem Ergebnis entfernt werden.

.PARAMETER MinCoveragePercent
    Gruppen unter diesem Abdeckungsgrad werden nicht per AD aufgelöst und nicht ausgegeben (spart AD-Abfragen).

.PARAMETER Top
    Anzahl der Teilabdeckungs-Kandidaten, die ausgegeben werden, wenn keine Gruppe vollständig abdeckt.
    Verschachtelte Gruppen und Ausnahmedetails werden für diese Top-N-Gruppen ermittelt.

.PARAMETER ShowPartial
    Teilabdeckungs-Kandidaten (Top N) auch dann ausgeben, wenn es vollständig abdeckende Gruppen gibt.

.PARAMETER Server
    Optional: Domänencontroller bzw. Global Catalog für die AD-Abfragen (z. B. 'dc01.contoso.local'
    oder 'dc01.contoso.local:3268' für den GC bei Forest-übergreifenden SIDs).

.PARAMETER ExportPath
    Optional: Ordner für CSV-Export (Gruppen_*.csv und Ausnahmen_*.csv, Semikolon, UTF-8 mit BOM).

.PARAMETER MaxExamples
    Anzahl der Beispielpfade, die je eindeutiger ACL gespeichert werden (Standard 10).

.PARAMETER MinimalGroupSet
    Ermittelt die kleinste Gruppenauswahl für maximalen Lesezugriff. Berücksichtigt Deny-ACEs (eine Gruppe
    mit Deny kann den Zugriff einer anderen aufheben und wird dann nicht gewählt) und die Standardgruppen
    (Jeder, Authentifizierte Benutzer, Domänen-Benutzer, BUILTIN\Users), die jeder Benutzer ohnehin hat.
    Es werden nur AD-Gruppen vorgeschlagen (keine Benutzer-ACEs, keine Builtin-Gruppen).

.PARAMETER ReadOnlyGroupsOnly
    Für -MinimalGroupSet nur Gruppen zulassen, die auf keinem Objekt Schreib-/Lösch-/Rechte-Bits vergeben.

.PARAMETER MaxGroups
    Obergrenze für die Größe des Gruppensets (Standard 25).

.PARAMETER ResolveUsers
    Berechnet je Benutzer den effektiven Lesezugriff aus allen Gruppen (transitiv). Ausgabe: Benutzer mit
    vollem Zugriff, sonst die besten Kandidaten (Top N) mit Ausnahmen.

.PARAMETER IncludeDisabledUsers
    Deaktivierte Benutzerkonten bei -ResolveUsers mit auswerten (Standard: überspringen).

.PARAMETER BaselineSid
    Zusätzliche SIDs, die jeder Benutzer im Token hat (z. B. 'S-1-5-2' Netzwerk). Standard: Jeder (S-1-1-0),
    Authentifizierte Benutzer (S-1-5-11), BUILTIN\Users (S-1-5-32-545) und Domänen-Benutzer (-513).

.PARAMETER PassThru
    Ergebnisobjekte (Gruppen, Gruppenset-Schritte, Benutzer; erkennbar am Typnamen PSCollections.ReadAccess.*) in die
    Pipeline ausgeben. Ohne -PassThru werden die Ergebnisse als Tabellen in der Konsole angezeigt.

.PARAMETER ComputerName
    Server, dessen lokale Administratorengruppe aufgelöst wird (per Invoke-Command/Get-LocalGroupMember).
    Ohne Angabe wird bei lokalem Pfad der lokale Rechner verwendet, bei UNC-Pfad nichts aufgelöst.

.EXAMPLE
    .\Get-ReadAccessGroups.ps1 -Path '\\fs01\daten\Projekte'

.EXAMPLE
    .\Get-ReadAccessGroups.ps1 -Path 'D:\Daten\Vertrieb' -ExcludeGroupName 'Domain Admins' -ExportPath C:\Temp -ShowPartial

.EXAMPLE
    # Schneller Vorabcheck, nur Ordner, nur drei Ebenen tief
    .\Get-ReadAccessGroups.ps1 -Path 'D:\Daten' -FoldersOnly -Depth 3

.NOTES
    Version : 1.1.0
    Änderungen 1.1.0: -MinimalGroupSet, -ReadOnlyGroupsOnly, -MaxGroups, -ResolveUsers, -IncludeDisabledUsers,
                      -BaselineSid, -ComputerName; Deny-ACEs ohne eigenes Allow werden jetzt miterfasst.
    Voraussetzungen: PowerShell 7+, RSAT ActiveDirectory-Modul, Leserecht auf die Berechtigungen (READ_CONTROL)
    aller Objekte (z. B. Administrator/Sicherungs-Operator, am besten direkt auf dem Dateiserver ausführen).

    Grenzen:
      * Nur NTFS-Rechte, keine Freigabeberechtigungen.
      * Deny-ACEs werden je SID ausgewertet. Ein Deny auf eine ANDERE Gruppe, in der Mitglieder zusätzlich
        stecken, ist keine Effective-Access-Berechnung pro Benutzer und wird nicht berücksichtigt.
      * Die Abdeckung einer Gruppe basiert nur auf deren eigenen ACEs. Gruppen, die in eine Gruppe mit
        Zugriff verschachtelt sind, erben diesen Zugriff und werden als "VerschachtelteGruppen" angezeigt.
      * Verzeichnis-Reparse-Points (Junctions/Symlinks) werden nicht verfolgt (Schleifenschutz).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [ValidateRange(-1, 100000)]
    [int]$Depth = -1,

    [switch]$FoldersOnly,
    [switch]$IncludeBuiltIn,
    [string[]]$ExcludeGroupName,

    [ValidateRange(0, 100)]
    [double]$MinCoveragePercent = 0,

    [ValidateRange(1, 1000)]
    [int]$Top = 10,

    [switch]$ShowPartial,
    [string]$Server,
    [string]$ExportPath,

    [ValidateRange(1, 1000)]
    [int]$MaxExamples = 10,

    [switch]$MinimalGroupSet,
    [switch]$ReadOnlyGroupsOnly,

    [ValidateRange(1, 200)]
    [int]$MaxGroups = 25,

    [switch]$ResolveUsers,
    [switch]$IncludeDisabledUsers,
    [string[]]$BaselineSid,
    [string]$ComputerName,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ScriptVersion = '1.1.0'

#region Konstanten und Zustand
# Zugriffsmasken ohne Synchronize-Bit (wird in der Praxis immer mitgesetzt, ist aber für "lesen" irrelevant)
$script:ReadData   = 0x1        # ReadData / ListDirectory
$script:MaskRead   = 0x20089    # ReadData + ReadEA + ReadAttributes + ReadPermissions
$script:MaskRX     = 0x200A9    # Read + ExecuteFile/Traverse
$script:MaskModify = 0x301BF    # ReadAndExecute + Write + Delete
$script:MaskFull   = 0xF01FF    # FullControl
$script:MaskWrite  = 0xD0156    # Write/Append/WriteEA/WriteAttr/DeleteSubdirs/Delete/ChangePerms/TakeOwnership

$script:RankNames = @{
    0 = 'Kein Lesezugriff'
    1 = 'Benutzerdefiniert (ReadData)'
    2 = 'Read'
    3 = 'ReadAndExecute'
    4 = 'Modify'
    5 = 'FullControl'
}

# Well-known SIDs, die per Default ausgeblendet werden (kein AD-Lookup nötig)
$script:WellKnownPatterns = @(
    '^S-1-[0-4]-\d+$'                 # NULL, Everyone, Local, Creator Owner/Group
    '^S-1-5-\d{1,2}$'                 # NT AUTHORITY (SYSTEM, Authenticated Users, Interactive ...)
    '^S-1-5-32-\d+$'                  # BUILTIN (Administratoren, Benutzer ...)
    '^S-1-5-(64|80|82|83|113|114)-'   # Authentication Authority, Dienste, virtuelle Konten
    '^S-1-(15|16)-'                   # App-Container, Mandatory Levels
)

$script:AclTable        = @{}   # SDDL -> Eintrag (Id, Count, Examples, Map, Protected)
$script:SidCache        = @{}   # SID  -> aufgelöstes Prinzipal (inkl. negativer Treffer)
$script:NestedCache     = @{}   # DN   -> Namen verschachtelter Gruppen
$script:MemberCache     = @{}   # DN   -> Benutzer (transitive Mitglieder einer Gruppe)
$script:UserSidCache    = @{}   # SID  -> Benutzerdatensatz (oder $null)
$script:AclList         = @()   # ACL-Einträge als Array (Index = ACL-Nr.)
$script:AclWeight       = $null # Objektanzahl je ACL-Index
$script:AnyAllow        = $null # je ACL-Index: erlaubt irgendein Prinzipal Lesen?
$script:SidIndex        = @{}   # SID -> Allow-/Deny-Indexlisten (invertierter Index)
$script:ScanErrors      = [System.Collections.Generic.List[object]]::new()
$script:ScanErrorCount  = 0
$script:ObjectCount     = [long]0
$script:DirCount        = [long]0
$script:FileCount       = [long]0
$script:SkippedReparse  = [long]0
$script:AdQueryCount    = 0
$script:Stopwatch       = [System.Diagnostics.Stopwatch]::new()
$script:LastProgressMs  = [long]0
#endregion

#region Hilfsfunktionen
function ConvertTo-ExtendedPath {
    # Langpfad-Präfix, sonst scheitert GetNamedSecurityInfo bei Pfaden > 260 Zeichen
    param([Parameter(Mandatory)][string]$LiteralPath)
    if ($LiteralPath.Length -lt 240 -or $LiteralPath.StartsWith('\\?\')) { return $LiteralPath }
    if ($LiteralPath.StartsWith('\\')) { return '\\?\UNC\' + $LiteralPath.Substring(2) }
    return '\\?\' + $LiteralPath
}

function ConvertTo-LdapFilterValue {
    param([Parameter(Mandatory)][string]$Value)
    return $Value.Replace('\', '\5c').Replace('*', '\2a').Replace('(', '\28').Replace(')', '\29')
}

function Get-AdProperty {
    # Sicherer Property-Zugriff auf AD-Objekte (kein Fehler unter StrictMode, wenn Attribut fehlt)
    param($Object, [Parameter(Mandatory)][string]$Name)
    $p = $Object.PSObject.Properties[$Name]
    if ($null -ne $p) { return $p.Value }
    return $null
}

function Test-WellKnownSid {
    param([Parameter(Mandatory)][string]$Sid)
    foreach ($pattern in $script:WellKnownPatterns) {
        if ($Sid -match $pattern) { return $true }
    }
    return $false
}

function Get-AccessRank {
    param([int]$Rights)
    if (($Rights -band $script:MaskFull)   -eq $script:MaskFull)   { return 5 }
    if (($Rights -band $script:MaskModify) -eq $script:MaskModify) { return 4 }
    if (($Rights -band $script:MaskRX)     -eq $script:MaskRX)     { return 3 }
    if (($Rights -band $script:MaskRead)   -eq $script:MaskRead)   { return 2 }
    if (($Rights -band $script:ReadData)   -ne 0)                  { return 1 }
    return 0
}

function Get-FsSecurity {
    # Eigene Funktion, damit der Zugriff gekapselt (und testbar) ist.
    param([Parameter(Mandatory)][string]$LiteralPath, [Parameter(Mandatory)][bool]$IsDirectory)
    $ext      = ConvertTo-ExtendedPath -LiteralPath $LiteralPath
    $sections = [System.Security.AccessControl.AccessControlSections]::Access
    if ($IsDirectory) { return [System.Security.AccessControl.DirectorySecurity]::new($ext, $sections) }
    return [System.Security.AccessControl.FileSecurity]::new($ext, $sections)
}

function Get-ReadMap {
    <#
        Liefert je SID, die auf dem Objekt effektiv lesen darf, eine Info:
        Rank (0-5), Write (hat Schreib-/Lösch-/Rechte-Bits), Denied (Deny-ACE auf Lesen vorhanden).
        Rank 0 + Denied = Lesen durch Deny entzogen bzw. nur Deny vorhanden (relevant für Gruppenkombinationen).
    #>
    param([Parameter(Mandatory)][System.Security.AccessControl.FileSystemSecurity]$Security)

    $allow = @{}
    $deny  = @{}
    $inheritOnly = [System.Security.AccessControl.PropagationFlags]::InheritOnly

    foreach ($rule in $Security.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])) {
        # ACEs, die nur an Kindobjekte vererben, gelten nicht für dieses Objekt selbst
        if ($rule.PropagationFlags.HasFlag($inheritOnly)) { continue }

        $sid  = $rule.IdentityReference.Value
        $bits = [int]$rule.FileSystemRights
        if ($rule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow) {
            $allow[$sid] = if ($allow.ContainsKey($sid)) { $allow[$sid] -bor $bits } else { $bits }
        }
        else {
            $deny[$sid] = if ($deny.ContainsKey($sid)) { $deny[$sid] -bor $bits } else { $bits }
        }
    }

    $map  = @{}
    $sids = [System.Collections.Generic.HashSet[string]]::new([string[]]@(@($allow.Keys) + @($deny.Keys)))
    foreach ($sid in $sids) {
        $g = if ($allow.ContainsKey($sid)) { [int]$allow[$sid] } else { 0 }
        $d = if ($deny.ContainsKey($sid))  { [int]$deny[$sid] }  else { 0 }

        # Deny auf ReadData: Die SID liest nicht - und blockiert Lesen auch dann, wenn ein anderes Token-Mitglied erlaubt
        if (($d -band $script:ReadData) -ne 0) {
            $map[$sid] = [pscustomobject]@{ Rank = 0; Write = $false; Denied = $true }
            continue
        }
        $effective = $g -band (-bnot $d)
        if (($effective -band $script:ReadData) -ne 0) {
            $map[$sid] = [pscustomobject]@{
                Rank   = Get-AccessRank -Rights $effective
                Write  = (($effective -band $script:MaskWrite) -ne 0)
                Denied = $false
            }
        }
    }
    return $map
}
#endregion

#region Scan
function Add-ScanError {
    param([string]$ErrorPath, [string]$Message, [string]$Stage)
    $script:ScanErrorCount++
    if ($script:ScanErrors.Count -lt 1000) {
        $script:ScanErrors.Add([pscustomobject]@{ Pfad = $ErrorPath; Phase = $Stage; Meldung = $Message })
    }
}

function Add-ObjectAcl {
    param([Parameter(Mandatory)][string]$ObjectPath, [Parameter(Mandatory)][bool]$IsDirectory)

    try {
        $sec = Get-FsSecurity -LiteralPath $ObjectPath -IsDirectory $IsDirectory
    }
    catch {
        Add-ScanError -ErrorPath $ObjectPath -Message $_.Exception.Message -Stage 'ACL lesen'
        return
    }

    $sddl  = $sec.GetSecurityDescriptorSddlForm([System.Security.AccessControl.AccessControlSections]::Access)
    $entry = $script:AclTable[$sddl]
    if ($null -eq $entry) {
        $entry = [pscustomobject]@{
            Id        = 'ACL-{0:D4}' -f ($script:AclTable.Count + 1)
            Protected = $sec.AreAccessRulesProtected
            Count     = [long]0
            Examples  = [System.Collections.Generic.List[string]]::new()
            Map       = Get-ReadMap -Security $sec
        }
        $script:AclTable[$sddl] = $entry
    }
    $entry.Count++
    if ($entry.Examples.Count -lt $MaxExamples) { $entry.Examples.Add($ObjectPath) }

    $script:ObjectCount++
    if ($IsDirectory) { $script:DirCount++ } else { $script:FileCount++ }

    if (($script:ObjectCount % 200) -eq 0 -and ($script:Stopwatch.ElapsedMilliseconds - $script:LastProgressMs) -ge 500) {
        $script:LastProgressMs = $script:Stopwatch.ElapsedMilliseconds
        $rate = [math]::Round($script:ObjectCount / [math]::Max(1, $script:Stopwatch.Elapsed.TotalSeconds))
        $shown = if ($ObjectPath.Length -gt 90) { '...' + $ObjectPath.Substring($ObjectPath.Length - 87) } else { $ObjectPath }
        Write-Progress -Id 1 -Activity 'Berechtigungen werden ausgewertet' `
            -Status ('{0:N0} Objekte | {1:N0}/s | {2} eindeutige ACLs' -f $script:ObjectCount, $rate, $script:AclTable.Count) `
            -CurrentOperation $shown
    }
}

function Invoke-TreeScan {
    param([Parameter(Mandatory)][string]$Root)

    $opt = [System.IO.EnumerationOptions]::new()
    $opt.RecurseSubdirectories   = $false
    $opt.IgnoreInaccessible      = $false
    $opt.AttributesToSkip        = [System.IO.FileAttributes]0   # auch versteckte/System-Objekte
    $opt.ReturnSpecialDirectories = $false

    $stack = [System.Collections.Generic.Stack[System.Tuple[string, int]]]::new()
    $stack.Push([System.Tuple]::Create($Root, 0))

    while ($stack.Count -gt 0) {
        $item    = $stack.Pop()
        $dirPath = $item.Item1
        $level   = $item.Item2

        Add-ObjectAcl -ObjectPath $dirPath -IsDirectory $true

        try {
            $dirInfo = [System.IO.DirectoryInfo]::new($dirPath)
            foreach ($child in $dirInfo.EnumerateFileSystemInfos('*', $opt)) {
                if ($child -is [System.IO.DirectoryInfo]) {
                    if ($child.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
                        $script:SkippedReparse++
                        Write-Verbose "Reparse-Point übersprungen: $($child.FullName)"
                        continue
                    }
                    if ($Depth -lt 0 -or $level -lt $Depth) {
                        $stack.Push([System.Tuple]::Create($child.FullName, $level + 1))
                    }
                }
                elseif (-not $FoldersOnly) {
                    Add-ObjectAcl -ObjectPath $child.FullName -IsDirectory $false
                }
            }
        }
        catch {
            Add-ScanError -ErrorPath $dirPath -Message $_.Exception.Message -Stage 'Ordner auflisten'
        }
    }
    Write-Progress -Id 1 -Activity 'Berechtigungen werden ausgewertet' -Completed
}
#endregion

#region Auswertung und AD
function Get-SidAggregate {
    # Verdichtet alle eindeutigen ACLs zu einer Abdeckung je SID
    $agg = @{}
    foreach ($entry in $script:AclTable.Values) {
        foreach ($kv in $entry.Map.GetEnumerator()) {
            $sid  = $kv.Key
            $info = $kv.Value
            if (-not $agg.ContainsKey($sid)) {
                $agg[$sid] = [pscustomobject]@{
                    Sid = $sid; Covered = [long]0; MinRank = 99; MaxRank = 0; AnyWrite = $false; DeniedObjects = [long]0
                }
            }
            $a = $agg[$sid]
            if ($info.Rank -gt 0) {
                $a.Covered += $entry.Count
                if ($info.Rank -lt $a.MinRank) { $a.MinRank = $info.Rank }
                if ($info.Rank -gt $a.MaxRank) { $a.MaxRank = $info.Rank }
                if ($info.Write) { $a.AnyWrite = $true }
            }
            if ($info.Denied) { $a.DeniedObjects += $entry.Count }
        }
    }
    return $agg
}

function Resolve-PrincipalSid {
    # SID -> Prinzipal, mit Cache (auch für nicht gefundene SIDs)
    param([Parameter(Mandatory)][string]$Sid)

    if ($script:SidCache.ContainsKey($Sid)) { return $script:SidCache[$Sid] }

    if (Test-WellKnownSid -Sid $Sid) {
        $name = try { [System.Security.Principal.SecurityIdentifier]::new($Sid).Translate([System.Security.Principal.NTAccount]).Value } catch { $Sid }
        $result = [pscustomobject]@{ Sid = $Sid; Kind = 'WellKnown'; Name = $name; Dn = $null; Scope = $null }
    }
    else {
        $adParams = $script:AdParams
        $script:AdQueryCount++
        $obj = @(Get-ADObject @adParams -LDAPFilter "(objectSid=$Sid)" `
                -Properties sAMAccountName, objectClass, distinguishedName, groupType) | Select-Object -First 1

        if ($null -eq $obj) {
            $result = [pscustomobject]@{ Sid = $Sid; Kind = 'NotInAD'; Name = $Sid; Dn = $null; Scope = $null }
        }
        else {
            $class = [string](Get-AdProperty -Object $obj -Name 'objectClass')
            $sam   = Get-AdProperty -Object $obj -Name 'sAMAccountName'
            $dn    = Get-AdProperty -Object $obj -Name 'distinguishedName'
            $name  = if ($sam) { [string]$sam } else { $Sid }
            $kind  = switch ($class) { 'group' { 'Group' } 'user' { 'User' } 'computer' { 'Computer' } default { 'Other' } }
            $scope = $null
            if ($kind -eq 'Group') {
                $gt = Get-AdProperty -Object $obj -Name 'groupType'
                if ($null -ne $gt) {
                    $gt = [int]$gt
                    $scope = if ($gt -band 2) { 'Global' } elseif ($gt -band 4) { 'DomainLocal' } elseif ($gt -band 8) { 'Universal' } else { $null }
                }
            }
            $result = [pscustomobject]@{ Sid = $Sid; Kind = $kind; Name = $name; Dn = $dn; Scope = $scope }
        }
    }
    $script:SidCache[$Sid] = $result
    return $result
}

function Get-NestedGroupNames {
    # Alle (transitiv) verschachtelten Untergruppen in EINER Abfrage (LDAP_MATCHING_RULE_IN_CHAIN), mit Cache
    param([Parameter(Mandatory)][string]$GroupDn)

    if ($script:NestedCache.ContainsKey($GroupDn)) { return $script:NestedCache[$GroupDn] }
    $adParams = $script:AdParams
    $script:AdQueryCount++
    try {
        $filter = '(memberOf:1.2.840.113556.1.4.1941:={0})' -f (ConvertTo-LdapFilterValue -Value $GroupDn)
        $names  = @(Get-ADGroup @adParams -LDAPFilter $filter | ForEach-Object { $_.SamAccountName } | Sort-Object)
    }
    catch {
        Write-Warning "Verschachtelte Gruppen für '$GroupDn' nicht ermittelbar: $($_.Exception.Message)"
        $names = @('(Abfrage fehlgeschlagen)')
    }
    $script:NestedCache[$GroupDn] = $names
    return $names
}

function Get-AclExceptions {
    # Alle eindeutigen ACLs, auf denen die SID NICHT lesen darf (inkl. Objektanzahl und Beispielpfaden)
    param([Parameter(Mandatory)][string]$Sid, [Parameter(Mandatory)][string]$GroupName)
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in $script:AclTable.Values) {
        $info = $entry.Map[$Sid]
        if ($null -ne $info -and $info.Rank -gt 0) { continue }
        $reason = if ($null -ne $info -and $info.Denied) { 'Lesen durch Deny-ACE entzogen' } else { 'Kein Lese-ACE für die Gruppe' }
        $list.Add([pscustomobject]@{
            Gruppe                = $GroupName
            AclId                 = $entry.Id
            Grund                 = $reason
            Objekte               = $entry.Count
            VererbungUnterbrochen = $entry.Protected
            Beispielpfade         = ($entry.Examples -join ' | ')
        })
    }
    return @($list | Sort-Object -Property Objekte -Descending)
}

function Get-GroupResults {
    param([Parameter(Mandatory)][hashtable]$Aggregate, [Parameter(Mandatory)][long]$Total)

    $rows = [System.Collections.Generic.List[object]]::new()
    $ignoredBuiltIn = 0
    $ignoredOther   = 0

    foreach ($a in $Aggregate.Values) {
        if ($a.Covered -le 0) { continue }

        $full = ($a.Covered -eq $Total)
        $pct  = if ($full) { 100.0 } else { [math]::Floor(10000.0 * $a.Covered / $Total) / 100 }
        if ($pct -lt $MinCoveragePercent) { continue }

        if ((Test-WellKnownSid -Sid $a.Sid) -and -not $IncludeBuiltIn) { $ignoredBuiltIn++; continue }

        $p = Resolve-PrincipalSid -Sid $a.Sid
        if ($p.Kind -eq 'NotInAD' -and -not $IncludeBuiltIn) { $ignoredBuiltIn++; continue }
        if ($p.Kind -in 'User', 'Computer', 'Other') { $ignoredOther++; continue }

        if ($ExcludeGroupName) {
            $name = $p.Name
            if (@($ExcludeGroupName | Where-Object { $name -like $_ }).Count -gt 0) { continue }
        }

        $stufe = if ($a.MinRank -eq $a.MaxRank) { $script:RankNames[[int]$a.MaxRank] }
                 else { '{0} bis {1}' -f $script:RankNames[[int]$a.MinRank], $script:RankNames[[int]$a.MaxRank] }

        $rows.Add([pscustomobject]@{
            PSTypeName            = 'PSCollections.ReadAccess.Group'
            Gruppe                = $p.Name
            AbdeckungProzent      = $pct
            Stufe                 = $stufe
            AusnahmeObjekte       = $Total - $a.Covered
            NurLesend             = (-not $a.AnyWrite)
            Vollstaendig          = $full
            ObjekteMitZugriff     = $a.Covered
            ObjekteGesamt         = $Total
            DenyObjekte           = $a.DeniedObjects
            Typ                   = $p.Kind
            Scope                 = $p.Scope
            VerschachtelteGruppen = $null
            Ausnahmen             = @()
            Sid                   = $a.Sid
            DistinguishedName     = $p.Dn
        })
    }

    return [pscustomobject]@{
        Rows           = @($rows | Sort-Object -Property @{ Expression = 'AbdeckungProzent'; Descending = $true }, @{ Expression = 'Gruppe' })
        IgnoredBuiltIn = $ignoredBuiltIn
        IgnoredOther   = $ignoredOther
    }
}

function Set-DefaultDisplay {
    # Kompakte Tabellenansicht (4 Spalten), alle weiteren Eigenschaften bleiben abrufbar
    param(
        [Parameter(Mandatory)]$InputObject,
        [string[]]$Properties = @('Gruppe', 'AbdeckungProzent', 'Stufe', 'AusnahmeObjekte')
    )
    $set = [System.Management.Automation.PSPropertySet]::new('DefaultDisplayPropertySet', $Properties)
    $members = [System.Management.Automation.PSMemberInfo[]]@($set)
    $InputObject | Add-Member -MemberType MemberSet -Name PSStandardMembers -Value $members -Force
}
#endregion

#region Gruppenset und Benutzer (Token-Modell)
function Get-FirstItems {
    # Erste N Elemente ohne Select-Object (das würde den Typnamen der Objekte auf 'Selected.*' ändern)
    param([AllowEmptyCollection()][object[]]$Items, [int]$Count)
    $a = @($Items)
    if ($a.Count -le $Count) { return $a }
    return $a[0..($Count - 1)]
}

function Get-Percent {
    param([long]$Covered, [long]$Total)
    if ($Total -le 0) { return 0.0 }
    if ($Covered -ge $Total) { return 100.0 }
    return [math]::Floor(10000.0 * $Covered / $Total) / 100
}

function Get-SidDisplayName {
    param([string]$Sid)
    if ($script:SidCache.ContainsKey($Sid)) { return $script:SidCache[$Sid].Name }
    if ($Sid -eq 'S-1-5-32-544') { return 'BUILTIN\Administrators' }
    return $Sid
}

function New-SidIndex {
    # Invertierter Index: SID -> ACL-Indizes, auf denen sie lesen darf (Allow) bzw. Lesen blockiert (Deny)
    $script:AclList   = @($script:AclTable.Values)
    $n                = $script:AclList.Count
    $script:AclWeight = [long[]]::new($n)
    $script:AnyAllow  = [bool[]]::new($n)
    $tmp = @{}
    for ($i = 0; $i -lt $n; $i++) {
        $e = $script:AclList[$i]
        $script:AclWeight[$i] = $e.Count
        foreach ($kv in $e.Map.GetEnumerator()) {
            $t = $tmp[$kv.Key]
            if ($null -eq $t) {
                $t = [pscustomobject]@{
                    Allow = [System.Collections.Generic.List[int]]::new()
                    Rank  = [System.Collections.Generic.List[int]]::new()
                    Write = [System.Collections.Generic.List[bool]]::new()
                    Deny  = [System.Collections.Generic.List[int]]::new()
                }
                $tmp[$kv.Key] = $t
            }
            if ($kv.Value.Rank -gt 0) {
                $t.Allow.Add($i); $t.Rank.Add([int]$kv.Value.Rank); $t.Write.Add([bool]$kv.Value.Write)
                $script:AnyAllow[$i] = $true
            }
            if ($kv.Value.Denied) { $t.Deny.Add($i) }
        }
    }
    $script:SidIndex = @{}
    foreach ($kv in $tmp.GetEnumerator()) {
        $t = $kv.Value
        $maxRank = 0
        $minRank = 99
        foreach ($r in $t.Rank) { if ($r -gt $maxRank) { $maxRank = $r }; if ($r -lt $minRank) { $minRank = $r } }
        $script:SidIndex[$kv.Key] = [pscustomobject]@{
            Sid      = $kv.Key
            Allow    = $t.Allow.ToArray()
            Rank     = $t.Rank.ToArray()
            Write    = $t.Write.ToArray()
            Deny     = $t.Deny.ToArray()
            AnyWrite = $t.Write.Contains($true)
            MaxRank  = $maxRank
            MinRank  = $minRank
        }
    }
}

function Measure-TokenCoverage {
    # Effektiver Lesezugriff eines Tokens (Liste von SIDs): Lesen, wenn mindestens eine SID erlaubt und KEINE SID Deny hat
    param([Parameter(Mandatory)][string[]]$Sids)

    $n     = $script:AclList.Count
    $rank  = [int[]]::new($n)
    $write = [bool[]]::new($n)
    $deny  = [bool[]]::new($n)
    foreach ($sid in $Sids) {
        $ix = $script:SidIndex[$sid]
        if ($null -eq $ix) { continue }
        $a = $ix.Allow; $r = $ix.Rank; $w = $ix.Write
        for ($k = 0; $k -lt $a.Length; $k++) {
            $i = $a[$k]
            if ($r[$k] -gt $rank[$i]) { $rank[$i] = $r[$k] }
            if ($w[$k]) { $write[$i] = $true }
        }
        $d = $ix.Deny
        for ($k = 0; $k -lt $d.Length; $k++) { $deny[$d[$k]] = $true }
    }

    $covered = [long]0; $minRank = 99; $maxRank = 0; $anyWrite = $false
    $weights = $script:AclWeight
    for ($i = 0; $i -lt $n; $i++) {
        if ($rank[$i] -gt 0 -and -not $deny[$i]) {
            $covered += $weights[$i]
            if ($rank[$i] -lt $minRank) { $minRank = $rank[$i] }
            if ($rank[$i] -gt $maxRank) { $maxRank = $rank[$i] }
            if ($write[$i]) { $anyWrite = $true }
        }
    }
    return [pscustomobject]@{
        Covered = $covered; MinRank = $minRank; MaxRank = $maxRank; AnyWrite = $anyWrite
        RankArr = $rank; DenyArr = $deny
    }
}

function Get-UncoveredAcls {
    # Eindeutige ACLs, auf denen das Token NICHT lesen darf
    param(
        [Parameter(Mandatory)]$Measure,
        [Parameter(Mandatory)][string]$Label,
        [string]$LabelName = 'Benutzer',
        [string]$ReasonAllowExists = 'Kein Lese-ACE für eine SID im Token'
    )
    $list = [System.Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $script:AclList.Count; $i++) {
        if ($Measure.RankArr[$i] -gt 0 -and -not $Measure.DenyArr[$i]) { continue }
        $reason = if ($Measure.DenyArr[$i]) { 'Lesen durch Deny-ACE blockiert' }
                  elseif ($script:AnyAllow[$i]) { $ReasonAllowExists }
                  else { 'Kein Lese-ACE für irgendein Prinzipal' }
        $e = $script:AclList[$i]
        $h = [ordered]@{
            $LabelName            = $Label
            AclId                 = $e.Id
            Grund                 = $reason
            Objekte               = $e.Count
            VererbungUnterbrochen = $e.Protected
            Beispielpfade         = ($e.Examples -join ' | ')
        }
        $list.Add([pscustomobject]$h)
    }
    return @($list | Sort-Object -Property Objekte -Descending)
}

function Get-BaselineSids {
    # SIDs, die praktisch jeder Benutzer im Token hat (kostenlos, aber Deny darauf wirkt für alle)
    $list = [System.Collections.Generic.List[string]]::new()
    foreach ($s in 'S-1-1-0', 'S-1-5-11', 'S-1-5-32-545') { $list.Add($s) }
    $adParams = $script:AdParams
    try {
        $script:AdQueryCount++
        $domSid = (Get-ADDomain @adParams).DomainSID.Value
        $list.Add("$domSid-513")
    }
    catch { Write-Warning "Domänen-SID nicht ermittelbar, 'Domänen-Benutzer' fehlt in den Standardgruppen: $($_.Exception.Message)" }
    foreach ($s in $BaselineSid) { if ($s) { $list.Add($s) } }
    return [string[]]@($list | Select-Object -Unique)
}

function Test-SetCandidate {
    param([Parameter(Mandatory)][string]$Sid)
    $ix = $script:SidIndex[$Sid]
    if ($ReadOnlyGroupsOnly -and $ix.AnyWrite) { return $false }
    if (Test-WellKnownSid -Sid $Sid) { return $false }
    $p = Resolve-PrincipalSid -Sid $Sid
    if ($p.Kind -ne 'Group') { return $false }
    if ($ExcludeGroupName -and @($ExcludeGroupName | Where-Object { $p.Name -like $_ }).Count -gt 0) { return $false }
    return $true
}

function Get-MinimalGroupSet {
    <#
        Set-Cover-Problem (NP-schwer). Heuristik: Greedy nach größtem Zugewinn (Objektanzahl), danach
        Redundanzbereinigung. Deny-bewusst: Der Zugewinn einer Gruppe wird um Objekte gekürzt, die sie über
        Deny blockiert. Gruppen werden erst per AD aufgelöst, wenn sie als beste Wahl anstehen (wenige Abfragen).
        Gleichstand: lieber Gruppe ohne Schreibrechte, dann niedrigere Stufe.
    #>
    param([Parameter(Mandatory)][string[]]$BaselineSids)

    $n = $script:AclList.Count
    $w = $script:AclWeight
    $allowed = [bool[]]::new($n)
    $denied  = [bool[]]::new($n)
    foreach ($sid in $BaselineSids) {
        $ix = $script:SidIndex[$sid]
        if ($null -eq $ix) { continue }
        foreach ($i in $ix.Allow) { $allowed[$i] = $true }
        foreach ($i in $ix.Deny)  { $denied[$i]  = $true }
    }

    $candidates = [System.Collections.Generic.List[string]]::new()
    foreach ($sid in $script:SidIndex.Keys) {
        if ($BaselineSids -contains $sid) { continue }
        if ($script:SidIndex[$sid].Allow.Length -gt 0) { $candidates.Add($sid) }
    }

    $chosen   = [System.Collections.Generic.List[string]]::new()
    $rejected = [System.Collections.Generic.HashSet[string]]::new()

    while ($chosen.Count -lt $MaxGroups) {
        $gains = [System.Collections.Generic.List[object]]::new()
        foreach ($sid in $candidates) {
            if ($rejected.Contains($sid) -or $chosen.Contains($sid)) { continue }
            $ix = $script:SidIndex[$sid]
            $g  = [long]0
            $a  = $ix.Allow
            for ($k = 0; $k -lt $a.Length; $k++) {
                $i = $a[$k]
                if (-not $allowed[$i] -and -not $denied[$i]) { $g += $w[$i] }
            }
            if ($g -le 0) { continue }
            $d = $ix.Deny
            for ($k = 0; $k -lt $d.Length; $k++) {
                $i = $d[$k]
                if ($allowed[$i] -and -not $denied[$i]) { $g -= $w[$i] }
            }
            if ($g -gt 0) {
                $gains.Add([pscustomobject]@{ Sid = $sid; Gain = $g; Write = $ix.AnyWrite; MaxRank = $ix.MaxRank })
            }
        }
        if ($gains.Count -eq 0) { break }

        $sorted = $gains | Sort-Object -Property @{ Expression = 'Gain'; Descending = $true }, 'Write', 'MaxRank', 'Sid'
        $picked = $null
        foreach ($c in $sorted) {
            if (Test-SetCandidate -Sid $c.Sid) { $picked = $c.Sid; break }
            [void]$rejected.Add($c.Sid)
        }
        if ($null -eq $picked) { break }

        $chosen.Add($picked)
        $ix = $script:SidIndex[$picked]
        foreach ($i in $ix.Allow) { $allowed[$i] = $true }
        foreach ($i in $ix.Deny)  { $denied[$i]  = $true }
    }

    # Redundanzbereinigung: Gruppen entfernen, ohne die der Zugriff nicht schlechter wird
    $cov = (Measure-TokenCoverage -Sids ([string[]](@($BaselineSids) + $chosen.ToArray()))).Covered
    for ($j = $chosen.Count - 1; $j -ge 0; $j--) {
        $trial = [System.Collections.Generic.List[string]]::new($chosen)
        $trial.RemoveAt($j)
        $m = Measure-TokenCoverage -Sids ([string[]](@($BaselineSids) + $trial.ToArray()))
        if ($m.Covered -ge $cov) { $chosen.RemoveAt($j); $cov = $m.Covered }
    }

    $total  = $script:ObjectCount
    $baseM  = Measure-TokenCoverage -Sids $BaselineSids
    $prev   = $baseM.Covered
    $steps  = [System.Collections.Generic.List[object]]::new()
    for ($k = 0; $k -lt $chosen.Count; $k++) {
        $sub = [string[]](@($BaselineSids) + $chosen.GetRange(0, $k + 1).ToArray())
        $m   = Measure-TokenCoverage -Sids $sub
        $ix  = $script:SidIndex[$chosen[$k]]
        $p   = Resolve-PrincipalSid -Sid $chosen[$k]
        $stufe = if ($ix.MinRank -eq $ix.MaxRank) { $script:RankNames[[int]$ix.MaxRank] }
                 else { '{0} bis {1}' -f $script:RankNames[[int]$ix.MinRank], $script:RankNames[[int]$ix.MaxRank] }
        $row = [pscustomobject]@{
            PSTypeName                 = 'PSCollections.ReadAccess.SetStep'
            Reihenfolge                = $k + 1
            Gruppe                     = $p.Name
            ZugewinnObjekte            = $m.Covered - $prev
            KumulierteAbdeckungProzent = Get-Percent -Covered $m.Covered -Total $total
            Stufe                      = $stufe
            NurLesend                  = (-not $ix.AnyWrite)
            Scope                      = $p.Scope
            Sid                        = $p.Sid
            DistinguishedName          = $p.Dn
        }
        Set-DefaultDisplay -InputObject $row -Properties 'Reihenfolge', 'Gruppe', 'ZugewinnObjekte', 'KumulierteAbdeckungProzent'
        $steps.Add($row)
        $prev = $m.Covered
    }

    $finalM = Measure-TokenCoverage -Sids ([string[]](@($BaselineSids) + $chosen.ToArray()))
    return [pscustomobject]@{
        Steps           = @($steps)
        BaselineCovered = $baseM.Covered
        BaselinePercent = Get-Percent -Covered $baseM.Covered -Total $total
        FinalCovered    = $finalM.Covered
        FinalPercent    = Get-Percent -Covered $finalM.Covered -Total $total
        Uncovered       = @(Get-UncoveredAcls -Measure $finalM -Label 'Gruppenset' -LabelName 'Ziel' `
                              -ReasonAllowExists 'Nur über nicht verwendbare Prinzipale (Benutzer, Builtin, ausgeschlossene/schreibende Gruppen) oder Gruppen mit Deny-Konflikt')
    }
}

function ConvertTo-UserRecord {
    param([Parameter(Mandatory)]$AdUser)
    $sidObj = Get-AdProperty -Object $AdUser -Name 'SID'
    return [pscustomobject]@{
        Sid     = [string]$sidObj.Value
        Name    = [string](Get-AdProperty -Object $AdUser -Name 'SamAccountName')
        Enabled = [bool](Get-AdProperty -Object $AdUser -Name 'Enabled')
    }
}

function Get-AdUserBySid {
    param([Parameter(Mandatory)][string]$Sid)
    if ($script:UserSidCache.ContainsKey($Sid)) { return $script:UserSidCache[$Sid] }
    $adParams = $script:AdParams
    $script:AdQueryCount++
    $u = @(Get-ADUser @adParams -LDAPFilter "(objectSid=$Sid)") | Select-Object -First 1
    $rec = if ($null -eq $u) { $null } else { ConvertTo-UserRecord -AdUser $u }
    $script:UserSidCache[$Sid] = $rec
    return $rec
}

function Get-GroupMemberUsers {
    # Alle Benutzer, die (transitiv) Mitglied der Gruppe sind - eine Abfrage je Gruppe, gecacht
    param([Parameter(Mandatory)][string]$GroupDn)
    if ($script:MemberCache.ContainsKey($GroupDn)) { return $script:MemberCache[$GroupDn] }
    $adParams = $script:AdParams
    $script:AdQueryCount++
    $filter = '(&(objectCategory=person)(objectClass=user)(memberOf:1.2.840.113556.1.4.1941:={0}))' -f (ConvertTo-LdapFilterValue -Value $GroupDn)
    $members = @(Get-ADUser @adParams -LDAPFilter $filter | ForEach-Object { ConvertTo-UserRecord -AdUser $_ })
    $script:MemberCache[$GroupDn] = $members
    return $members
}

function Add-UserToken {
    param([Parameter(Mandatory)][hashtable]$Users, [Parameter(Mandatory)]$User, [Parameter(Mandatory)][string]$TokenSid)
    $rec = $Users[$User.Sid]
    if ($null -eq $rec) {
        $rec = [pscustomobject]@{
            Sid = $User.Sid; Name = $User.Name; Enabled = $User.Enabled
            Token = [System.Collections.Generic.HashSet[string]]::new()
        }
        $Users[$User.Sid] = $rec
    }
    [void]$rec.Token.Add($TokenSid)
}

function Get-LocalAdminMemberSids {
    # Mitglieder der lokalen Administratorengruppe (S-1-5-32-544) des Dateiservers
    try {
        if ($ComputerName) {
            return @(Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                    Get-LocalGroupMember -SID 'S-1-5-32-544' | ForEach-Object { $_.SID.Value }
                })
        }
        if ($Path.StartsWith('\\')) {
            Write-Warning 'UNC-Pfad ohne -ComputerName: Mitglieder der lokalen Administratorengruppe werden nicht aufgelöst (Admins über BUILTIN\Administrators fehlen ggf. in der Benutzerliste).'
            return @()
        }
        return @(Get-LocalGroupMember -SID 'S-1-5-32-544' | ForEach-Object { $_.SID.Value })
    }
    catch {
        Write-Warning "Lokale Administratoren nicht ermittelbar: $($_.Exception.Message)"
        return @()
    }
}

function Get-UserResults {
    param([Parameter(Mandatory)][string[]]$BaselineSids)

    $total = $script:ObjectCount
    $users = @{}
    $groups = [System.Collections.Generic.List[object]]::new()

    # 1. Alle relevanten SIDs auflösen (gecacht): Gruppen sammeln, direkt berechtigte Benutzer anlegen
    $sids = @($script:SidIndex.Keys)
    $i = 0
    foreach ($sid in $sids) {
        $i++
        if ($BaselineSids -contains $sid -or (Test-WellKnownSid -Sid $sid)) { continue }
        Write-Progress -Id 2 -Activity 'SIDs per AD auflösen' -Status "$i / $($sids.Count)" -PercentComplete (100 * $i / $sids.Count)
        $p = Resolve-PrincipalSid -Sid $sid
        if ($p.Kind -eq 'Group' -and $p.Dn) { $groups.Add($p) }
        elseif ($p.Kind -eq 'User') {
            $u = Get-AdUserBySid -Sid $sid
            if ($null -ne $u) { Add-UserToken -Users $users -User $u -TokenSid $sid }
        }
    }
    Write-Progress -Id 2 -Activity 'SIDs per AD auflösen' -Completed

    # 2. Transitive Mitglieder je relevanter Gruppe
    $i = 0
    foreach ($g in $groups) {
        $i++
        Write-Progress -Id 3 -Activity 'Gruppenmitglieder auflösen' -Status "$i / $($groups.Count): $($g.Name)" -PercentComplete (100 * $i / [math]::Max(1, $groups.Count))
        foreach ($m in @(Get-GroupMemberUsers -GroupDn $g.Dn)) { Add-UserToken -Users $users -User $m -TokenSid $g.Sid }
    }
    Write-Progress -Id 3 -Activity 'Gruppenmitglieder auflösen' -Completed

    # 3. Lokale Administratoren: Mitglieder erhalten S-1-5-32-544 im Token
    $adminSid = 'S-1-5-32-544'
    if ($script:SidIndex.ContainsKey($adminSid)) {
        foreach ($msid in @(Get-LocalAdminMemberSids)) {
            if (Test-WellKnownSid -Sid $msid) { continue }
            $p = Resolve-PrincipalSid -Sid $msid
            if ($p.Kind -eq 'Group' -and $p.Dn) {
                foreach ($m in @(Get-GroupMemberUsers -GroupDn $p.Dn)) { Add-UserToken -Users $users -User $m -TokenSid $adminSid }
            }
            elseif ($p.Kind -eq 'User') {
                $u = Get-AdUserBySid -Sid $msid
                if ($null -ne $u) { Add-UserToken -Users $users -User $u -TokenSid $adminSid }
            }
        }
    }

    # 4. Effektiver Zugriff je Benutzer
    $rows = [System.Collections.Generic.List[object]]::new()
    $skippedDisabled = 0
    foreach ($rec in $users.Values) {
        if (-not $rec.Enabled -and -not $IncludeDisabledUsers) { $skippedDisabled++; continue }

        $token = [System.Collections.Generic.List[string]]::new()
        $token.AddRange($BaselineSids)
        if ($rec.Sid -match '^(S-1-5-21-\d+-\d+-\d+)-\d+$') { $token.Add("$($Matches[1])-513") }   # Domänen-Benutzer der Heimatdomäne
        $token.AddRange([string[]]@($rec.Token))
        $tokenArr = [string[]]@($token | Select-Object -Unique)

        $m = Measure-TokenCoverage -Sids $tokenArr
        if ($m.Covered -le 0) { continue }

        $full  = ($m.Covered -eq $total)
        $stufe = if ($m.MinRank -eq $m.MaxRank) { $script:RankNames[[int]$m.MaxRank] }
                 else { '{0} bis {1}' -f $script:RankNames[[int]$m.MinRank], $script:RankNames[[int]$m.MaxRank] }
        $via = @($rec.Token | Where-Object { $script:SidIndex.ContainsKey($_) -and $script:SidIndex[$_].Allow.Length -gt 0 } |
                 ForEach-Object { Get-SidDisplayName -Sid $_ } | Sort-Object)

        $rows.Add([pscustomobject]@{
            PSTypeName       = 'PSCollections.ReadAccess.User'
            Benutzer         = $rec.Name
            AbdeckungProzent = Get-Percent -Covered $m.Covered -Total $total
            Stufe            = $stufe
            AusnahmeObjekte  = $total - $m.Covered
            NurLesend        = (-not $m.AnyWrite)
            Vollstaendig     = $full
            Aktiv            = $rec.Enabled
            ViaGruppen       = $via
            Ausnahmen        = @()
            Sid              = $rec.Sid
            TokenSids        = $tokenArr
        })
    }

    $sortedRows = @($rows | Sort-Object -Property @{ Expression = 'AbdeckungProzent'; Descending = $true }, @{ Expression = 'Benutzer' })
    $full     = @($sortedRows | Where-Object { $_.Vollstaendig })
    $partial  = @(Get-FirstItems -Items @($sortedRows | Where-Object { -not $_.Vollstaendig }) -Count $Top)
    $selected = if ($full.Count -eq 0 -or $ShowPartial) { @($full) + @($partial) } else { @($full) }

    foreach ($r in $selected) {
        if (-not $r.Vollstaendig) {
            $m = Measure-TokenCoverage -Sids $r.TokenSids
            $r.Ausnahmen = @(Get-UncoveredAcls -Measure $m -Label $r.Benutzer -LabelName 'Benutzer')
        }
        Set-DefaultDisplay -InputObject $r -Properties 'Benutzer', 'AbdeckungProzent', 'Stufe', 'AusnahmeObjekte'
    }

    return [pscustomobject]@{
        Selected        = @($selected)
        FullCount       = $full.Count
        UserCount       = $users.Count
        SkippedDisabled = $skippedDisabled
    }
}

function Show-ResultTable {
    # Tabellenausgabe in der Konsole (ohne -PassThru); Spalten kommen aus dem DefaultDisplayPropertySet
    param([AllowEmptyCollection()][object[]]$Objects)
    if (-not $PassThru -and @($Objects).Count -gt 0) { Write-Host (($Objects | Format-Table -AutoSize | Out-String -Width 200).TrimEnd()) }
}

function Write-ExceptionPreview {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Exceptions, [string]$Csv = 'CSV')
    if ($Exceptions.Count -eq 0) { return }
    Write-Host ("`nGrößte Ausnahmen für '{0}' ({1} eindeutige ACLs, alle im {2}-Export):" -f $Name, $Exceptions.Count, $Csv) -ForegroundColor Yellow
    foreach ($x in ($Exceptions | Select-Object -First 5)) {
        Write-Host ("  {0} | {1:N0} Objekte | Vererbung getrennt: {2} | {3}" -f $x.AclId, $x.Objekte, $x.VererbungUnterbrochen, $x.Grund)
        $examples = ($x.Beispielpfade -split ' \| ' | Select-Object -First 2) -join ' | '
        Write-Host ("      z. B. {0}" -f $examples)
    }
}
#endregion

#region Hauptablauf
function Start-Audit {
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if ($fullPath.Length -gt 3) { $fullPath = $fullPath.TrimEnd('\') }
    if (-not [System.IO.Directory]::Exists($fullPath)) { throw "Basisverzeichnis nicht gefunden: $fullPath" }

    try { Import-Module ActiveDirectory -ErrorAction Stop }
    catch { throw "ActiveDirectory-Modul (RSAT) nicht verfügbar: $($_.Exception.Message)" }

    $script:AdParams = @{}
    if ($Server) { $script:AdParams['Server'] = $Server }

    Write-Host ("Get-ReadAccessGroups v{0} | Basis: {1}" -f $script:ScriptVersion, $fullPath) -ForegroundColor Cyan
    Write-Host ("Umfang: {0}{1}" -f $(if ($FoldersOnly) { 'nur Ordner' } else { 'Ordner und Dateien' }),
                $(if ($Depth -ge 0) { ", Tiefe $Depth" } else { ', unbegrenzte Tiefe' }))

    # --- 1. Scan ---
    $script:Stopwatch.Restart()
    Invoke-TreeScan -Root $fullPath
    $scanSeconds = [math]::Round($script:Stopwatch.Elapsed.TotalSeconds, 1)

    $total = $script:ObjectCount
    if ($total -eq 0) { throw 'Es konnte kein einziges Objekt ausgewertet werden (siehe Fehler oben/Rechte prüfen).' }

    Write-Host ("Scan fertig in {0} s: {1:N0} Objekte ({2:N0} Ordner, {3:N0} Dateien), {4:N0} eindeutige ACLs." -f
                $scanSeconds, $total, $script:DirCount, $script:FileCount, $script:AclTable.Count)
    if ($script:ScanErrorCount -gt 0) {
        Write-Warning ("{0:N0} Objekte/Ordner nicht auswertbar (Zugriff verweigert o. ä.) und NICHT in der Abdeckung enthalten. Details: `$script:ScanErrors bzw. -ExportPath." -f $script:ScanErrorCount)
    }
    if ($script:SkippedReparse -gt 0) {
        Write-Host ("{0:N0} Verzeichnis-Reparse-Points (Junctions/Symlinks) nicht verfolgt." -f $script:SkippedReparse) -ForegroundColor DarkYellow
    }

    # --- 2. Abdeckung je SID, AD-Auflösung (gecacht) ---
    $aggregate = Get-SidAggregate
    $res       = Get-GroupResults -Aggregate $aggregate -Total $total
    $rows      = @($res.Rows)

    $full    = @($rows | Where-Object { $_.Vollstaendig })
    $partial = @(Get-FirstItems -Items @($rows | Where-Object { -not $_.Vollstaendig }) -Count $Top)
    $selected = if ($full.Count -eq 0 -or $ShowPartial) { @($full) + @($partial) } else { @($full) }

    # --- 3. Verschachtelung und Ausnahmen für die ausgewählten Gruppen ---
    foreach ($r in $selected) {
        if ($r.Typ -eq 'Group' -and $r.DistinguishedName) {
            $r.VerschachtelteGruppen = @(Get-NestedGroupNames -GroupDn $r.DistinguishedName)
        }
        if (-not $r.Vollstaendig) {
            $r.Ausnahmen = @(Get-AclExceptions -Sid $r.Sid -GroupName $r.Gruppe)
        }
        Set-DefaultDisplay -InputObject $r
    }

    # --- 4. Zusammenfassung ---
    Write-Host ''
    if ($full.Count -gt 0) {
        Write-Host ("{0} Gruppe(n) mit Lesezugriff auf ALLE {1:N0} Objekte:" -f $full.Count, $total) -ForegroundColor Green
    }
    else {
        Write-Host ("Keine Gruppe hat auf allen {0:N0} Objekten Lesezugriff. Beste Kandidaten (Top {1}):" -f $total, $Top) -ForegroundColor Yellow
    }
    Write-Host ("(AD-Abfragen: {0}, SIDs im Cache: {1}; ausgeblendet: {2} Well-known/lokal/verwaist, {3} Benutzer-/Computer-ACEs)" -f
                $script:AdQueryCount, $script:SidCache.Count, $res.IgnoredBuiltIn, $res.IgnoredOther) -ForegroundColor DarkGray

    Show-ResultTable -Objects $selected
    $nested = @($selected | Where-Object { $_.VerschachtelteGruppen -and $_.VerschachtelteGruppen.Count -gt 0 })
    foreach ($r in $nested) {
        Write-Host ("  {0}: erbt Zugriff an verschachtelte Gruppen -> {1}" -f $r.Gruppe, ($r.VerschachtelteGruppen -join ', ')) -ForegroundColor DarkCyan
    }

    $bestList = @($selected | Where-Object { -not $_.Vollstaendig })
    $best     = if ($bestList.Count -gt 0) { $bestList[0] } else { $null }
    if ($null -ne $best) { Write-ExceptionPreview -Name $best.Gruppe -Exceptions @($best.Ausnahmen) -Csv 'Ausnahmen_*.csv' }
    Write-Host ''

    # --- 4b. Minimales Gruppenset (optional) ---
    $setResult  = $null
    $userResult = $null
    if ($MinimalGroupSet -or $ResolveUsers) {
        New-SidIndex
        $baseline = Get-BaselineSids
    }
    if ($MinimalGroupSet) {
        $setResult = Get-MinimalGroupSet -BaselineSids $baseline
        Write-Host '--- Minimales Gruppenset ---' -ForegroundColor Cyan
        Write-Host ("Standardgruppen (Jeder, Authentifizierte Benutzer, Domänen-Benutzer, BUILTIN\Users) decken bereits {0} % ab." -f $setResult.BaselinePercent)
        if ($setResult.Steps.Count -eq 0) {
            Write-Host 'Keine weitere Gruppe bringt Zugewinn.' -ForegroundColor Yellow
        }
        else {
            Write-Host ("{0} Gruppe(n) zusätzlich ergeben {1} % der {2:N0} Objekte (Heuristik: Greedy + Redundanzbereinigung, minimal nicht beweisbar)." -f
                        $setResult.Steps.Count, $setResult.FinalPercent, $total) -ForegroundColor Green
            Show-ResultTable -Objects $setResult.Steps
        }
        if ($setResult.Uncovered.Count -gt 0) {
            $openObjects = ($setResult.Uncovered | Measure-Object -Property Objekte -Sum).Sum
            Write-Host ("Nicht erreichbar mit diesem Set: {0:N0} Objekte in {1} eindeutigen ACLs." -f $openObjects, $setResult.Uncovered.Count) -ForegroundColor Yellow
            Write-ExceptionPreview -Name 'Gruppenset' -Exceptions @($setResult.Uncovered) -Csv 'Gruppenset_Offen_*.csv'
        }
        Write-Host ''
    }

    # --- 4c. Benutzer mit Zugriff auf alles (optional, ganz am Schluss) ---
    if ($ResolveUsers) {
        $userResult = Get-UserResults -BaselineSids $baseline
        Write-Host '--- Benutzer ---' -ForegroundColor Cyan
        Write-Host ("{0} Benutzerkonten ausgewertet ({1} deaktivierte übersprungen), AD-Abfragen gesamt: {2}." -f
                    $userResult.UserCount, $userResult.SkippedDisabled, $script:AdQueryCount) -ForegroundColor DarkGray
        if ($userResult.FullCount -gt 0) {
            Write-Host ("{0} Benutzer mit Lesezugriff auf ALLE {1:N0} Objekte." -f $userResult.FullCount, $total) -ForegroundColor Green
        }
        else {
            Write-Host ("Kein Benutzer hat auf allen {0:N0} Objekten Lesezugriff. Beste Kandidaten:" -f $total) -ForegroundColor Yellow
        }
        Show-ResultTable -Objects $userResult.Selected
        $bestUserList = @($userResult.Selected | Where-Object { -not $_.Vollstaendig })
        $bestUser     = if ($bestUserList.Count -gt 0) { $bestUserList[0] } else { $null }
        if ($null -ne $bestUser) { Write-ExceptionPreview -Name $bestUser.Benutzer -Exceptions @($bestUser.Ausnahmen) -Csv 'Ausnahmen_Benutzer_*.csv' }
        Write-Host ''
    }

    # --- 5. Export ---
    if ($ExportPath) {
        if (-not (Test-Path -LiteralPath $ExportPath)) { $null = New-Item -ItemType Directory -Path $ExportPath -Force }
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $csvGroups = Join-Path $ExportPath "Gruppen_$stamp.csv"
        $selected | Select-Object Gruppe, AbdeckungProzent, Stufe, NurLesend, ObjekteMitZugriff, ObjekteGesamt,
            AusnahmeObjekte, DenyObjekte, Typ, Scope,
            @{ n = 'VerschachtelteGruppen'; e = { @($_.VerschachtelteGruppen) -join '; ' } }, Sid, DistinguishedName |
            Export-Csv -LiteralPath $csvGroups -NoTypeInformation -Delimiter ';' -Encoding utf8BOM
        Write-Host "CSV: $csvGroups"

        $exceptions = @($selected | ForEach-Object { $_.Ausnahmen })
        if ($exceptions.Count -gt 0) {
            $csvEx = Join-Path $ExportPath "Ausnahmen_$stamp.csv"
            $exceptions | Export-Csv -LiteralPath $csvEx -NoTypeInformation -Delimiter ';' -Encoding utf8BOM
            Write-Host "CSV: $csvEx"
        }
        if ($script:ScanErrors.Count -gt 0) {
            $csvErr = Join-Path $ExportPath "Fehler_$stamp.csv"
            $script:ScanErrors | Export-Csv -LiteralPath $csvErr -NoTypeInformation -Delimiter ';' -Encoding utf8BOM
            Write-Host "CSV: $csvErr"
        }
    }

    if ($ExportPath -and $null -ne $setResult) {
        if ($setResult.Steps.Count -gt 0) {
            $f = Join-Path $ExportPath "Gruppenset_$stamp.csv"
            $setResult.Steps | Select-Object Reihenfolge, Gruppe, ZugewinnObjekte, KumulierteAbdeckungProzent, Stufe, NurLesend, Scope, Sid, DistinguishedName |
                Export-Csv -LiteralPath $f -NoTypeInformation -Delimiter ';' -Encoding utf8BOM
            Write-Host "CSV: $f"
        }
        if ($setResult.Uncovered.Count -gt 0) {
            $f = Join-Path $ExportPath "Gruppenset_Offen_$stamp.csv"
            $setResult.Uncovered | Export-Csv -LiteralPath $f -NoTypeInformation -Delimiter ';' -Encoding utf8BOM
            Write-Host "CSV: $f"
        }
    }
    if ($ExportPath -and $null -ne $userResult) {
        $f = Join-Path $ExportPath "Benutzer_$stamp.csv"
        $userResult.Selected | Select-Object Benutzer, AbdeckungProzent, Stufe, NurLesend, AusnahmeObjekte, Aktiv,
            @{ n = 'ViaGruppen'; e = { @($_.ViaGruppen) -join '; ' } }, Sid |
            Export-Csv -LiteralPath $f -NoTypeInformation -Delimiter ';' -Encoding utf8BOM
        Write-Host "CSV: $f"
        $ux = @($userResult.Selected | ForEach-Object { $_.Ausnahmen })
        if ($ux.Count -gt 0) {
            $f = Join-Path $ExportPath "Ausnahmen_Benutzer_$stamp.csv"
            $ux | Export-Csv -LiteralPath $f -NoTypeInformation -Delimiter ';' -Encoding utf8BOM
            Write-Host "CSV: $f"
        }
    }

    if ($PassThru) {
        $result = @($selected)
        if ($null -ne $setResult)  { $result += @($setResult.Steps) }
        if ($null -ne $userResult) { $result += @($userResult.Selected) }
        return $result
    }
}

Start-Audit
#endregion
