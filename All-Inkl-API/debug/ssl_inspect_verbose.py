import os
import sys
from kas_sdk import KasClient

# --- Configuration ---
TARGET_HSTS_AGE = 31536000
FORCE_HTTPS_VAL = 'Y'
TARGET_HOST = "myhost.mydomain.com"

def check_settings_verbose(itm):
    print("--- Analysing Settings ---")
    
    # 1. SSL Active Check
    is_active_std = itm.get('ssl_certificate_is_active', 'N')
    is_active_sni = itm.get('ssl_certificate_sni_is_active', 'N')
    print(f"Raw 'ssl_certificate_is_active': '{is_active_std}'")
    print(f"Raw 'ssl_certificate_sni_is_active': '{is_active_sni}'")
    
    ssl_active = (is_active_std == 'Y') or (is_active_sni.lower() in ['y', 'j', 'yes', 'ja', 'true', '1'])
    print(f"-> Interpreted SSL Active: {ssl_active}")

    # 2. Force HTTPS Check
    force_std = itm.get('ssl_certificate_force_https', 'N')
    force_sni = itm.get('ssl_certificate_sni_force_https', 'N')
    print(f"Raw 'ssl_certificate_force_https': '{force_std}'")
    print(f"Raw 'ssl_certificate_sni_force_https': '{force_sni}'")
    
    curr_force = force_sni if force_sni else force_std
    if not curr_force: curr_force = 'N'
    print(f"-> Interpreted Force HTTPS: '{curr_force}' (Target: '{FORCE_HTTPS_VAL}')")

    # 3. HSTS Check
    hsts_std = itm.get('ssl_certificate_hsts_max_age', 0)
    hsts_sni = itm.get('ssl_certificate_sni_hsts_max_age', 0)
    print(f"Raw 'ssl_certificate_hsts_max_age': '{hsts_std}'")
    print(f"Raw 'ssl_certificate_sni_hsts_max_age': '{hsts_sni}'")
    
    curr_hsts = hsts_sni if hsts_sni else hsts_std
    try:
        curr_hsts = int(curr_hsts)
    except (ValueError, TypeError):
        curr_hsts = 0
    print(f"-> Interpreted HSTS Age: {curr_hsts} (Target: {TARGET_HSTS_AGE})")
    
    # Decision
    if curr_force == FORCE_HTTPS_VAL and curr_hsts == TARGET_HSTS_AGE:
        print("=> DECISION: OK (Already ENFORCED)")
    else:
        print("=> DECISION: UPDATE NEEDED")

def main():
    kas_login = os.environ.get('KAS_LOGIN')
    kas_pass = os.environ.get('KAS_PASS')
    kas_auth_type = os.environ.get('KAS_AUTH_TYPE', 'plain')

    print(f"--- Verbose Debug for {TARGET_HOST} ---")
    client = KasClient(kas_login=kas_login, kas_auth_data=kas_pass, kas_auth_type=kas_auth_type)

    print(f"Fetching details for '{TARGET_HOST}'...")
    # Try Subdomain first since it looks like one
    try:
        details = client.subdomain.get_subdomains(subdomain_name=TARGET_HOST)
        if not details:
            print("Not found in subdomains, trying domains...")
            details = client.domain.get_domains(domain_name=TARGET_HOST)
            
        if details and isinstance(details, list) and len(details) > 0:
            item = details[0]
            print("--- Raw Item Data ---")
            # Sort keys for readability
            for k in sorted(item.keys()):
                if 'ssl' in k:
                    print(f"{k}: '{item[k]}'")
            
            check_settings_verbose(item)
            
        else:
            print("FAILED (No details returned for host).")

    except Exception as e:
        print(f"ERROR: {e}")

if __name__ == "__main__":
    main()
