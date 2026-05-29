# Architektur-Übersicht – Certificates Toolkit

---

## Stack

| Schicht | Technologie |
|---------|-------------|
| Orchestrierung | PowerShell 7.0+ (`Generate-Certificate.ps1`) |
| Zertifikatsanforderung | `certreq.exe` → ADCS Enterprise CA |
| PFX → PEM | PSPKI-Modul (`Convert-PfxToPem`) |
| Zertifikatsketten-Export | .NET `X509Chain` (inline, kein externes Modul) |
| VMware-Deployment | VMware.PowerCLI (`VMware.VimAutomation.Core`) |
| Konfiguration | JSON-Dateien (`config.json`, `vmware-config.json`) |
| Auth | keine (lokale Maschinenrechte + interaktiver vCenter-Credential-Prompt) |
| Datenbank | keine |
| Build | keine |

---

## Systemstruktur – Zertifikatsgenerierung

```mermaid
flowchart TD
    A["Generate-Certificate.ps1<br />(Orchestrator)"] --> B{Modus?}
    B -->|"Config-Modus (Standard)"| C["config.json<br />(N Zertifikate)"]
    B -->|"Single-Modus (-HostnameFQDN)"| D["CLI-Parameter"]
    C --> E["New-Certificate()"]
    D --> E
    E --> F["Request-Certificate.ps1<br />certreq -new / -submit / -accept"]
    F --> G[("ADCS<br />Enterprise CA")]
    G --> F
    F --> H["hostname.pfx<br />(LocalMachine-Store → Export → Store-Cleanup)"]
    H --> I["Convert-PfxToPem<br />(PSPKI-Modul)"]
    H --> J["Export-CertificateChain<br />(.NET X509Chain, try/finally dispose)"]
    I --> K["friendlyname.pem<br />(Key + Cert kombiniert)"]
    I --> L["Split-Pem"]
    J --> M["friendlyname_ca_chain.pem"]
    L --> N["friendlyname_privatekey.pem"]
    L --> O["friendlyname_certificate.pem"]
```

---

## Systemstruktur – VMware-Deployment

```mermaid
flowchart TD
    A["Replace-VMWare-Certificates.ps1"] --> B["vmware-config.json<br />(vCenter-Topologie)"]
    A --> C["CertificateResults[]<br />(Ausgabe von Generate-Certificate.ps1)"]
    B --> D["Phase 0: Connect-VIServer<br />(alle vCenter vorab verbinden)"]
    C --> D
    D --> E["Phase 1: CA-Chain Upload<br />Add-VITrustedCertificate"]
    E --> F["Phase 2: Abgelaufene Certs entfernen<br />Remove-VITrustedCertificate"]
    F --> G["Phase 3: ESXi-Hosts<br />Maintenance on → Set-VIMachineCertificate → Maintenance off<br />(try/catch je Host)"]
    G --> H["Phase 4: vCenter Machine Cert<br />Set-VIMachineCertificate → Services restart"]
    H --> I["Disconnect-VIServer<br />(finally-Block)"]
```

---

## VMware-Deployment: Phasenfolge und Skip-Optionen

```mermaid
stateDiagram-v2
    [*] --> Verbunden : Connect-VIServer (alle vCenter)
    Verbunden --> CA_Upload : Phase 1 – CA-Chain
    CA_Upload --> Cleanup : Phase 2 – Expired Cleanup
    Cleanup --> ESXi : Phase 3 – ESXi Certs
    ESXi --> ESXi : nächster ESXi-Host (Fehler isoliert je Host)
    ESXi --> vCenter : Phase 4 – vCenter Cert
    vCenter --> [*] : Disconnect (finally)

    CA_Upload --> Cleanup : -SkipCaChainUpload
    Cleanup --> ESXi : -SkipExpiredCleanup
    ESXi --> vCenter : -SkipEsxi
    vCenter --> [*] : -SkipVcenter + Disconnect
```

---

## Modul-Verantwortlichkeiten

```
Generate-Certificate.ps1          → Orchestrierung: Config/CLI lesen, New-Certificate() aufrufen, PSCustomObject-Ergebnisse zurückgeben
Request-Certificate.ps1           → ADCS-Anfrage via certreq.exe, PFX-Export aus LocalMachine-Store, Store-Cleanup
Replace-VMWare-Certificates.ps1   → Phasiertes Cert-Deployment auf vCenter/ESXi via PowerCLI
Export-CertificateChain()         → CA-Kette aus PFX via .NET X509Chain extrahieren und als PEM schreiben
Split-Pem()                       → Kombinierten PEM (Key + Cert) in zwei separate Dateien aufteilen
Initialize-Module()               → PSPKI-Modul bei Bedarf installieren und importieren
Resolve-Param()                   → CLI-Parameter gegen Script-Defaults auflösen (Single-Modus)
Get-PropertyOrDefault()           → JSON-Objekt-Property gegen Config-Defaults auflösen (Config-Modus)
Find-CertResult()                 → PSCustomObject für einen Hostnamen aus CertificateResults[] suchen
Read-CertFiles()                  → Cert- und Key-PEM-Inhalte aus Dateipfaden im CertResult lesen
```

---

## Datenfluss – Übergabe zwischen den Skripten

```mermaid
flowchart LR
    A["Generate-Certificate.ps1"] -->|"PSCustomObject[]<br />HostnameFQDN, PfxPath,<br />PemPath, CaChainPath,<br />CertificatePath, PrivateKeyPath"| B["Replace-VMWare-Certificates.ps1"]
    A -->|"schreibt"| C[("Dateisystem<br />C:\\temp\\certs\\")]
    B -->|"liest"| C
```

---

## Entscheidungsrelevante Constraints

| Constraint | Auswirkung |
|-----------|-----------|
| Windows-only (`certreq.exe`, LocalMachine-Store) | Nicht auf Linux/macOS ausführbar |
| Admin-Rechte erforderlich | `certreq.exe` schreibt in LocalMachine-Store |
| ADCS Enterprise CA erreichbar | Kein Offline-CA- oder Standalone-CA-Support |
| vCenter **zuletzt** ersetzen | `Set-VIMachineCertificate` auf vCenter löst Services-Restart aus → API-Verbindung bricht |
| ESXi in Maintenance-Modus | Zertifikatstausch auf laufendem Host nicht möglich |
| PSPKI-Modul | Wird auto-installiert; erfordert Internetzugang oder lokal verfügbares Modul |
| Einzel-CA-Annahme | `Replace-VMWare-Certificates.ps1` lädt nur eine CA-Chain (die aus `CertificateResults[0]`); Warnung bei mehreren distinct Pfaden |
