"""
SSL/HSTS Enforcement Script
===========================

Scans all domains and subdomains in the KAS account.
If SSL is active on a host, it ensures:
1. HTTPS is forced (ssl_certificate_force_https = 'Y')
2. HSTS is active with max-age of 1 year (ssl_certificate_hsts_max_age = 31536000)

Usage:
    python ensure_ssl_hsts.py

Environment Variables:
    KAS_LOGIN
    KAS_PASS
    KAS_AUTH_TYPE (optional, default 'plain')
"""

import os
import sys
from kas_sdk import KasClient

# --- Configuration ---
TARGET_HSTS_AGE = 31536000  # 1 Year in seconds
FORCE_HTTPS_VAL = 'Y'

def get_existing_keys(item):
    """
    Extracts SSL keys from a domain/subdomain item dict.
    Returns None if keys are missing (which means we can't safely update).
    """
    # Keys required by update_ssl to re-submit existing certs
    # Try standard keys first, then SNI keys
    key = item.get('ssl_certificate_sni_key') or item.get('ssl_certificate_key')
    crt = item.get('ssl_certificate_sni_crt') or item.get('ssl_certificate_crt')
    bundle = item.get('ssl_certificate_sni_bundle') or item.get('ssl_certificate_bundle')

    # If keys are empty strings, treat as None
    if not key: key = None
    if not crt: crt = None

    if not key or not crt:
        return None
    
    return {
        'key': key,
        'crt': crt,
        'bundle': bundle if bundle else ''
    }

def process_host(client, host_name, item, host_type, is_dry_run):
    """
    Checks and updates a single host (domain or subdomain).
    """
    print(f"[{host_type}] {host_name}...", end=" ")

    # 1. Check if SSL is active
    # KAS API inconsistency: 
    # - Domains use 'ssl_certificate_is_active' = 'Y'
    # - Subdomains use 'ssl_certificate_sni_is_active' = 'j' (German 'ja'?) or 'Y'
    # - Sometimes 'ssl_certificate_sni' = 'Y' is the flag
    
    is_active_std = item.get('ssl_certificate_is_active', 'N')
    is_active_sni = item.get('ssl_certificate_sni_is_active', 'N')
    
    # Check for any positive value
    ssl_active = (is_active_std == 'Y') or (is_active_sni.lower() in ['y', 'j', 'yes', 'ja', 'true', '1'])
    
    if not ssl_active:
        print("SKIP (SSL not active)")
        return

    # 2. Check current settings
    def check_settings(itm):
        # Subdomains might use 'ssl_certificate_sni_force_https'
        force_std = itm.get('ssl_certificate_force_https', 'N')
        force_sni = itm.get('ssl_certificate_sni_force_https', 'N')
        
        curr_force = force_sni if force_sni else force_std
        # Note: KAS sometimes returns empty string for 'N' or missing? Assume 'N' if empty
        if not curr_force: curr_force = 'N'

        hsts_std = itm.get('ssl_certificate_hsts_max_age', 0)
        hsts_sni = itm.get('ssl_certificate_sni_hsts_max_age', 0)
        
        curr_hsts = hsts_sni if hsts_sni else hsts_std
        
        try:
            curr_hsts = int(curr_hsts)
        except (ValueError, TypeError):
            curr_hsts = 0
            
        return curr_force, curr_hsts

    current_force, current_hsts = check_settings(item)

    if current_force == FORCE_HTTPS_VAL and current_hsts == TARGET_HSTS_AGE:
        print("OK (Already enforced)")
        return

    # 3. Prepare for Update
    print("NEEDS UPDATE.")
    
    # Check keys - bulk fetch often omits keys
    keys = get_existing_keys(item)
    
    if not keys:
        print(f"   -> Keys missing or settings incomplete. Fetching details for '{host_name}'...", end=" ")
        try:
            if host_type == "DOMAIN":
                details = client.domain.get_domains(domain_name=host_name)
            else:
                details = client.subdomain.get_subdomains(subdomain_name=host_name)
                
            if details and isinstance(details, list) and len(details) > 0:
                item = details[0]
                keys = get_existing_keys(item)
                
                if keys:
                    # Re-check settings with fresh data!
                    current_force, current_hsts = check_settings(item)
                    if current_force == FORCE_HTTPS_VAL and current_hsts == TARGET_HSTS_AGE:
                        print("OK (Verified: Already enforced).")
                        return
                    else:
                        print("Confirmed update needed.")
                else:
                    print("STILL MISSING KEYS.")
            else:
                print("FAILED (No details returned).")
                
        except Exception as e:
            print(f"ERROR fetching details: {e}")

    if not keys:
        print(f"   ! ERROR: SSL is active but keys are missing in response. Cannot update safely.")
        return

    print(f"   -> Enforcing HTTPS and HSTS ({TARGET_HSTS_AGE}s)...", end=" ")

    if is_dry_run:
        print("[DRY-RUN] Would update settings now.")
        return

    try:
        success = client.ssl.update_ssl(
            hostname=host_name,
            ssl_certificate_is_active='Y',
            ssl_certificate_force_https=FORCE_HTTPS_VAL,
            ssl_certificate_hsts_max_age=TARGET_HSTS_AGE,
            ssl_certificate_sni_key=keys['key'],
            ssl_certificate_sni_crt=keys['crt'],
            ssl_certificate_sni_bundle=keys['bundle']
        )
        
        if success:
            print("SUCCESS.")
        else:
            print("FAILED (API returned False).")
            
    except Exception as e:
        print(f"ERROR: {e}")

def main():
    kas_login = os.environ.get('KAS_LOGIN')
    kas_pass = os.environ.get('KAS_PASS')
    kas_auth_type = os.environ.get('KAS_AUTH_TYPE', 'plain')
    
    # Check for Dry-Run flag
    # We want to enable TRUE reads but MOCK writes.
    # The SDK's default dry_run mode returns mock reads, which we don't want.
    # So we handle the flag manually and hide it from the SDK.
    script_dry_run = os.environ.get('KAS_DRY_RUN', '').lower() in ('true', '1', 'yes')
    
    if script_dry_run:
        print("!!! DRY-RUN MODE ACTIVE: Reading real data, but WRITES are disabled. !!!")
        # Remove from env so SDK doesn't see it and allows real reads
        if 'KAS_DRY_RUN' in os.environ:
            del os.environ['KAS_DRY_RUN']

    if not kas_login or not kas_pass:
        print("Error: KAS_LOGIN and KAS_PASS environment variables must be set.")
        sys.exit(1)

    print("--- Starting SSL/HSTS Enforcement Scan ---")
    print(f"Target HSTS Max Age: {TARGET_HSTS_AGE}")
    print(f"Force HTTPS: {FORCE_HTTPS_VAL}")
    print("------------------------------------------")

    client = KasClient(kas_login=kas_login, kas_auth_data=kas_pass, kas_auth_type=kas_auth_type)

    # 1. Process Domains
    print("[Scanning Domains]")
    try:
        domains = client.domain.get_domains()
        print(f"Found {len(domains)} domains.")
        if isinstance(domains, list):
            for d in domains:
                name = d.get('domain_name')
                if name:
                    process_host(client, name, d, "DOMAIN", script_dry_run)
    except Exception as e:
        print(f"Error fetching domains: {e}")

    # 2. Process Subdomains
    print("[Scanning Subdomains]")
    try:
        subdomains = client.subdomain.get_subdomains()
        print(f"Found {len(subdomains)} subdomains.")
        if isinstance(subdomains, list):
            for s in subdomains:
                name = s.get('subdomain_name')
                if name:
                    process_host(client, name, s, "SUBDOMAIN", script_dry_run)
    except Exception as e:
        print(f"Error fetching subdomains: {e}")

    print("--- Scan Complete ---")

if __name__ == "__main__":
    main()
