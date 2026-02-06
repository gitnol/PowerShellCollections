"""
All-Inkl KAS HSTS Automatisierung
=================================

Dieses Skript automatisiert das Setzen des HTTP Strict Transport Security (HSTS) Headers
für Domains und Subdomains beim Hosting-Anbieter All-Inkl.com.

Hintergrund:
Die All-Inkl API (KAS) bietet keine einfache Methode, nur HSTS zu aktivieren, ohne
die bestehenden SSL-Zertifikate neu zu übermitteln. Dieses Skript liest daher
zuerst die existierenden Zertifikats-Keys aus und sendet diese zusammen mit den
neuen HSTS-Einstellungen zurück.

Features:
- Umgeht Probleme mit Python SOAP-Bibliotheken (zeep) durch "Raw XML" Requests.
- Robuster XML-Parser, der auch API-Fehlermeldungen (Faults) korrekt interpretiert.
- Automatische Erkennung, ob es sich um eine Hauptdomain oder Subdomain handelt.
- "Nothing to do"-Erkennung: Meldet Erfolg, wenn Einstellungen bereits korrekt waren.

Voraussetzungen:
    pip install requests

Lizenz: MIT
"""

import requests
import json
import xml.etree.ElementTree as ET
import time
from typing import Dict, Optional, Any

# --- KONFIGURATION -----------------------------------------------------------

# Deine KAS Zugangsdaten (Login, z.B. w0123456)
KAS_USER = "DEIN_KAS_LOGIN"
KAS_PASS = "DEIN_KAS_PASSWORT"

# HSTS Max Age in Sekunden
# 31536000 = 1 Jahr (Empfohlen für TISAX / BitSight Rating "A")
TARGET_MAX_AGE = 31536000 

# Liste der zu bearbeitenden Domains
# Das Skript erkennt automatisch, ob es sich um Haupt- oder Subdomains handelt.
DOMAINS = [
    "example.com",
    "www.example.com",
    "subdomain.example.com",
    "service.test-domain.de"
]

# Offizieller API-Endpunkt
SOAP_URL = "https://kasapi.kasserver.com/soap/KasApi.php"

# -----------------------------------------------------------------------------

class KasSoapClient:
    """
    Ein robuster Client für die All-Inkl KAS SOAP API.
    Kapselt die Authentifizierung, XML-Erstellung und das Parsing der Antworten.
    """
    
    def __init__(self, user: str, password: str, api_url: str = SOAP_URL):
        """
        Initialisiert den Client.
        
        :param user: KAS Login (z.B. w012345)
        :param password: KAS Passwort
        :param api_url: URL zum SOAP Endpunkt
        """
        self.user = user
        self.password = password
        self.api_url = api_url

    def _send_request(self, action: str, params: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        Sendet einen Raw-SOAP Request an die API.
        
        Wir bauen das XML manuell, da viele SOAP-Bibliotheken (wie zeep) Probleme
        mit der WSDL-Definition oder der verschachtelten Map-Struktur von All-Inkl haben.
        
        :param action: Der Name der KAS-Aktion (z.B. 'get_subdomains', 'update_ssl')
        :param params: Ein Dictionary mit den Parametern für die Aktion
        :return: Ein Dictionary mit der Antwort oder None bei Verbindungsfehlern
        """
        # Authentifizierung und Parameter in JSON verpacken (für den SOAP Body)
        req_data = {
            'kas_login': self.user,
            'kas_auth_type': 'plain',
            'kas_auth_data': self.password,
            'kas_action': action,
            'KasRequestParams': params
        }
        json_payload = json.dumps(req_data)
        
        # Manuelles Bauen des SOAP Envelopes
        soap_body = f"""<?xml version="1.0" encoding="UTF-8"?>
        <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <SOAP-ENV:Body>
            <ns1:KasApi xmlns:ns1="urn:xmethods-delayed-quotes">
                <KasRequest xsi:type="xsd:string">{json_payload}</KasRequest>
            </ns1:KasApi>
        </SOAP-ENV:Body>
        </SOAP-ENV:Envelope>"""

        headers = {
            'Content-Type': 'text/xml; charset=utf-8', 
            'User-Agent': 'KAS-HSTS-Updater/1.0'
        }

        try:
            response = requests.post(self.api_url, data=soap_body, headers=headers)
            # Wir nutzen nicht raise_for_status(), da SOAP Faults oft HTTP 500 werfen,
            # wir aber den Inhalt der XML-Antwort lesen müssen, um den Fehler zu verstehen.
            return self._parse_soap_map(response.content)
        except Exception as e:
            print(f"[ERROR] HTTP Request fehlgeschlagen: {e}")
            return None

    def _parse_soap_map(self, xml_content: bytes) -> Dict[str, Any]:
        """
        Wandelt die XML-Antwort der API in ein Python Dictionary um.
        
        Die API gibt Maps in einer Listenstruktur zurück (<item><key>...</key><value>...</value>).
        Zudem werden SOAP Faults (Fehler) erkannt und in ein lesbares Format gebracht.
        
        :param xml_content: Der Raw-Body der Antwort
        :return: Ein Dictionary mit den Daten oder Fehlerinformationen
        """
        try:
            root = ET.fromstring(xml_content)
            
            # 1. Prüfen auf SOAP Faults (z.B. "nothing_to_do" oder "kas_password_incorrect")
            for elem in root.iter():
                if 'faultstring' in elem.tag and elem.text:
                    # Wir geben den Fehler strukturiert zurück
                    return {'ReturnString': 'FALSE', 'Error': elem.text.strip()}

            # 2. Suche nach dem <return> Knoten (Erfolgsfall)
            return_node = None
            for elem in root.iter():
                if 'return' in elem.tag:
                    return_node = elem
                    break
            
            if return_node is None:
                return {} # Leere Antwort

            # 3. Parsen der Item-Liste zu einem Dict
            result_dict = {}
            for item in return_node.iter('item'):
                key_node = None
                value_node = None
                # Suche Kinderknoten (ignoriert Namespaces)
                for child in item:
                    if 'key' in child.tag: key_node = child
                    elif 'value' in child.tag: value_node = child
                
                if key_node is not None and value_node is not None and key_node.text:
                    result_dict[key_node.text] = value_node.text.strip() if value_node.text else ""
                    
            return result_dict

        except ET.ParseError as e:
            print(f"[XML ERROR] Konnte Antwort nicht parsen: {e}")
            return {}

    def get_ssl_data(self, domain: str) -> Optional[Dict[str, str]]:
        """
        Versucht, die SSL-Daten (Keys, Zertifikate) für eine Domain abzurufen.
        
        Implementiert eine Fallback-Strategie:
        1. Versucht Abruf als Subdomain ('get_subdomains')
        2. Versucht Abruf als Hauptdomain ('get_domains')
        
        Dies ist notwendig, da KAS diese in unterschiedlichen Datenbanktabellen führt.
        
        :param domain: Der Domainname
        :return: Dict mit 'key', 'crt', 'bundle' oder None bei Fehler
        """
        print(f"   Lese Daten für {domain}...", end=" ")

        # Interne Helper-Funktion zum Extrahieren der Keys aus der Antwort
        def extract_keys(res):
            if res and 'ssl_certificate_sni_key' in res and res['ssl_certificate_sni_key']:
                return {
                    'key': res['ssl_certificate_sni_key'],
                    'crt': res['ssl_certificate_sni_crt'],
                    'bundle': res.get('ssl_certificate_sni_bundle', '')
                }
            return None

        # 1. Versuch: Als SUBDOMAIN abrufen
        res_sub = self._send_request('get_subdomains', {'subdomain_name': domain})
        keys = extract_keys(res_sub)
        
        if keys:
            print("[OK - Typ: Subdomain]")
            return keys
        
        # Check ob ein Fehler vorliegt, der nicht "leer" bedeutet
        if res_sub and 'Error' in res_sub:
            # Optional: Debugging ausgeben, falls nötig
            pass

        # 2. Versuch: Als HAUPTDOMAIN abrufen
        res_dom = self._send_request('get_domains', {'domain_name': domain})
        keys = extract_keys(res_dom)
        
        if keys:
            print("[OK - Typ: Hauptdomain]")
            return keys

        print("[FEHLER] Keine SSL-Daten gefunden (Domain existiert nicht oder kein SSL aktiv).")
        return None

    def set_hsts(self, domain: str, max_age: int) -> bool:
        """
        Führt den kompletten Update-Prozess für eine Domain durch.
        
        Ablauf:
        1. SSL-Daten holen (Backup der Keys)
        2. Update-Request mit HSTS-Settings und den alten Keys senden
        3. Ergebnis prüfen (inkl. 'nothing_to_do' Check)
        
        :param domain: Die zu bearbeitende Domain
        :param max_age: HSTS Zeit in Sekunden
        :return: True bei Erfolg, False bei Fehler
        """
        print(f"\n--- Bearbeite: {domain} ---")
        
        # 1. Daten holen
        ssl_data = self.get_ssl_data(domain)
        if not ssl_data:
            return False

        # 2. Update Parametrisieren
        update_params = {
            'hostname': domain,
            'ssl_certificate_is_active': 'Y',
            'ssl_certificate_force_https': 'Y',
            'ssl_certificate_hsts_max_age': max_age,
            # WICHTIG: Die bestehenden Keys müssen wieder mitgesendet werden!
            'ssl_certificate_sni_key': ssl_data['key'],
            'ssl_certificate_sni_crt': ssl_data['crt'],
            'ssl_certificate_sni_bundle': ssl_data['bundle']
        }

        # 3. Senden
        print(f"   Sende Update...", end=" ")
        result = self._send_request('update_ssl', update_params)
        
        # 4. Ergebnis auswerten
        if result:
            if result.get('ReturnString') == 'TRUE':
                print(f"[ERFOLG] HSTS aktiviert.")
                return True
            # KAS meldet Fehler, wenn die Einstellungen schon exakt so sind ("nothing_to_do")
            # Wir werten das als Erfolg.
            elif 'Error' in result and 'nothing_to_do' in result['Error']:
                print(f"[OK] War bereits korrekt gesetzt (API: nothing_to_do).")
                return True
            else:
                print(f"[FEHLER] API Rückmeldung: {result.get('Error', result)}")
                return False
        
        return False


# --- MAIN EXECUTION ----------------------------------------------------------
if __name__ == "__main__":
    if KAS_USER == "DEIN_KAS_LOGIN":
        print("Bitte konfiguriere zuerst KAS_USER und KAS_PASS im Skript!")
        exit(1)

    print(f"Starte KAS HSTS Update (Target Max Age: {TARGET_MAX_AGE}s)...")
    
    client = KasSoapClient(KAS_USER, KAS_PASS)
    
    for domain in DOMAINS:
        client.set_hsts(domain, TARGET_MAX_AGE)
        # WICHTIG: Flood Protection der API beachten (ca. 2s Pause)
        time.sleep(2)
        
    print("Fertig.")