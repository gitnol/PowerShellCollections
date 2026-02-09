"""
All-Inkl KAS HSTS Automation (SDK Version)
=========================================

Automates setting HTTP Strict Transport Security (HSTS) headers.

Logic:
1. Fetches existing SSL keys (needed to re-submit them).
2. Sets HSTS headers + Force HTTPS.
3. Uses KAS SDK.

License: MIT
"""

import time
import os
import sys
from kas_sdk import KasClient

# --- CONFIGURATION -----------------------------------------------------------

KAS_USER = os.environ.get('KAS_LOGIN', 'DEIN_KAS_LOGIN')
KAS_PASS = os.environ.get('KAS_PASS', 'DEIN_KAS_PASSWORT')

# HSTS Max Age (31536000 = 1 Year)
TARGET_MAX_AGE = 31536000 

# Domains to process
DOMAINS = [
    "example.com",
    "www.example.com",
    "subdomain.example.com",
    "service.test-domain.de"
]

# -----------------------------------------------------------------------------

def get_ssl_data(client: KasClient, domain: str):
    """
    Tries to fetch SSL keys via Subdomain or Domain service.
    """
    print(f"   Reading data for {domain}...", end=" ")

    def extract_keys(res_list, name_key):
        # Helper to find the specific domain in the list returned by SDK
        if not res_list: return None
        for item in res_list:
            # SDK returns dicts. Subdomain uses 'subdomain_name', Domain uses 'domain_name'
            if item.get(name_key) == domain:
                 if item.get('ssl_certificate_sni_key'):
                     return {
                        'key': item['ssl_certificate_sni_key'],
                        'crt': item['ssl_certificate_sni_crt'],
                        'bundle': item.get('ssl_certificate_sni_bundle', '')
                     }
        return None

    # 1. Try Subdomain
    # SDK get_subdomains() returns a List[Dict]
    subs = client.subdomain.get_subdomains() # Gets ALL subdomains (no filter param in SDK yet, or filter is optional?)
    # Wait, SDK get_subdomains signature is (subdomain_name=None). 
    # If we pass name, we might get a list with 1 item or empty.
    
    try:
        subs = client.subdomain.get_subdomains(subdomain_name=domain)
        keys = extract_keys(subs, 'subdomain_name')
        if keys:
            print("[OK - Type: Subdomain]")
            return keys
    except Exception:
        pass # Ignore and try domain

    # 2. Try Domain
    try:
        doms = client.domain.get_domains(domain_name=domain)
        keys = extract_keys(doms, 'domain_name')
        if keys:
            print("[OK - Type: Main Domain]")
            return keys
    except Exception:
        pass

    print("[ERROR] No SSL data found (Domain does not exist or SSL not active).")
    return None

def set_hsts(client: KasClient, domain: str, max_age: int):
    print(f"--- Processing: {domain} ---")
    
    # 1. Fetch Keys
    ssl_data = get_ssl_data(client, domain)
    if not ssl_data:
        return False

    # 2. Send Update
    print(f"   Sending Update...", end=" ")
    
    success = client.ssl.update_ssl(
        hostname=domain,
        ssl_certificate_is_active='Y',
        ssl_certificate_force_https='Y',
        ssl_certificate_hsts_max_age=max_age,
        ssl_certificate_sni_key=ssl_data['key'],
        ssl_certificate_sni_crt=ssl_data['crt'],
        ssl_certificate_sni_bundle=ssl_data['bundle']
    )
    
    if success:
        print("[SUCCESS] HSTS activated.")
    else:
        print("[FAILED] API reported error.")

def main():
    if "DEIN_KAS_LOGIN" in KAS_USER or "w0123456" in KAS_USER:
        print("ERROR: Please configure KAS_USER and KAS_PASS environment variables!")
        sys.exit(1)

    print(f"Starting KAS HSTS Update (Target Max Age: {TARGET_MAX_AGE}s)...")
    
    client = KasClient(KAS_USER, KAS_PASS)
    
    for domain in DOMAINS:
        set_hsts(client, domain, TARGET_MAX_AGE)
        time.sleep(2)
        
    print("Done.")

if __name__ == "__main__":
    main()
