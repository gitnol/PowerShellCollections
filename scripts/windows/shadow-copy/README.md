# Schattenkopien Aktivierung & Geplanter Task für Windows

Dieses Skript und die Anleitung ermöglichen die Aktivierung von Schattenkopien auf Laufwerk C: sowie die Einrichtung eines geplanten Tasks zur täglichen Erstellung von Schattenkopien.

---

## Voraussetzungen

- **Lokale administrative Rechte** sind zwingend erforderlich, um die Aktionen erfolgreich auszuführen.

---

## Schritt 1: Schattenkopien aktivieren

Führe zuerst die Funktion `Enable-ShadowCopyC` aus, um Schattenkopien auf Laufwerk C: zu aktivieren und 10 % des Speicherplatzes für die Schattenkopien zu reservieren:

```powershell
Enable-ShadowCopyC -MaxPercent 10
```

## Schritt 2: Geplanten Task erstellen

Erstelle anschließend den geplanten Task, der täglich eine Schattenkopie von Laufwerk C: anlegt. Stelle sicher, dass sich die XML-Datei für den Task entweder im aktuellen Ausführungsverzeichnis befindet oder gib den absoluten Pfad zur XML-Datei an.

```powershell
schtasks /create /tn "Snapshot_C_Täglich" /xml "Snapshot_C_Täglich.xml" /f
```

## Hinweise
Prüfe vor Ausführung, dass die XML-Datei korrekt und vollständig ist.

Der Task wird mit Systemrechten ausgeführt und benötigt daher keine zusätzliche Authentifizierung.

Die Schattenkopien werden automatisch gemäß der Task-Planung erstellt.