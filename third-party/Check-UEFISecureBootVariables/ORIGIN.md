# Herkunft

Fremder Code - nicht in diesem Repository entstanden und hier unveraendert
abgelegt.

| Feld     | Wert                                                            |
| -------- | --------------------------------------------------------------- |
| Projekt  | Check-UEFISecureBootVariables                                    |
| Quelle   | https://github.com/cjee21/Check-UEFISecureBootVariables          |
| Bezug    | ZIP-Download des `main`-Branches (daher urspruenglich der Ordnername `...-main`) |
| Stand    | enthaelt DBX-Updates bis 2025-10-14                              |
| Lizenz   | siehe Projekt-README bzw. LICENSE im Upstream-Repository         |

## Warum liegt das hier und nicht als Submodul?

Es wurde seinerzeit als ZIP hineinkopiert. Ein Git-Submodul waere besser:
Updates blieben nachvollziehbar und die ~40 Dateien wuerden die Dateizahl
dieses Repos nicht dominieren. Solange es kopiert bleibt, gilt:

> Hier nichts aendern. Aenderungen gehoeren upstream oder in einen eigenen
> Wrapper unter `scripts/security/secure-boot/`.

Ein Update besteht darin, den Ordnerinhalt komplett durch einen frischen
Download zu ersetzen und diese Datei zu aktualisieren.
