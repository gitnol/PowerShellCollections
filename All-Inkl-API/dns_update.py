"""
All-Inkl KAS DNS Updater (SDK Version)
=====================================
Features:
1. Uses the official KAS SDK for communication.
2. Handles DNS record creation and updates.
3. DRY-RUN mode supported.
"""

import time
import argparse
import sys
import os
from kas_sdk import KasClient

# --- CONFIGURATION -----------------------------------------------------------

KAS_USER = os.environ.get('KAS_LOGIN', 'DEIN_KAS_LOGIN')
KAS_PASS = os.environ.get('KAS_PASS', 'DEIN_KAS_PASSWORT')

ZONE_HOST = "" 
DEFAULT_IP = "1.2.3.4"

# Desired DNS Records
TARGET_RECORDS = {
    "": None,     # Root record
    "www": None,  # www subdomain
    "subdomain": None,
}

# -----------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="All-Inkl DNS Updater (SDK)")
    parser.add_argument("--dry-run", action="store_true", help="Activate simulation mode")
    args = parser.parse_args()

    if "DEIN_KAS_LOGIN" in KAS_USER or "w0123456" in KAS_USER:
        print("ERROR: Please configure KAS_LOGIN and KAS_PASS environment variables or edit script!")
        sys.exit(1)

    print(f"Connecting as {KAS_USER}...")
    client = KasClient(KAS_USER, KAS_PASS)

    # 1. Fetch current state
    print(f"Reading DNS zone '{ZONE_HOST}'...")
    curr_records = client.dns.get_dns_settings(zone_host=ZONE_HOST)
    
    # Map by record_name for easy lookup
    existing_map = {}
    for r in curr_records:
        r_name = r.get('record_name', '')
        if r_name not in existing_map: 
            existing_map[r_name] = []
        existing_map[r_name].append(r)

    print(f"Found {len(curr_records)} existing records.")
    print("-" * 60)

    for sub, target_ip in TARGET_RECORDS.items():
        wanted_ip = target_ip if target_ip else DEFAULT_IP
        disp_name = sub if sub else "(ROOT)"

        if sub in existing_map:
            records = existing_map[sub]
            
            # Check CNAME collision
            cname_record = next((r for r in records if r.get('record_type') == 'CNAME'), None)
            if cname_record:
                print(f" [WARN] {disp_name} is CNAME to {cname_record.get('record_data')}. Skipping.")
                continue

            # Check A Record
            a_record = next((r for r in records if r.get('record_type') == 'A'), None)
            
            if a_record:
                current_ip = a_record.get('record_data')
                rec_id = a_record.get('record_id')
                
                if current_ip != wanted_ip:
                    print(f" -> UPDATE {disp_name}: {current_ip} -> {wanted_ip}")
                    if not args.dry_run:
                        success = client.dns.update_dns_settings(
                            record_id=rec_id,
                            record_data=wanted_ip
                        )
                        print(f"    {'[SUCCESS]' if success else '[FAILED]'}")
                        time.sleep(1)
                else:
                    if args.dry_run:
                        print(f" [SKIP] {disp_name} is up to date.")
            else:
                # Name exists but no A record (maybe MX or TXT only?) -> Add A record
                print(f" -> CREATE {disp_name} -> {wanted_ip}")
                if not args.dry_run:
                    res = client.dns.add_dns_settings(
                        zone_host=ZONE_HOST,
                        record_type='A',
                        record_name=sub,
                        record_data=wanted_ip,
                        record_aux="0"
                    )
                    print(f"    {'[SUCCESS] ID: ' + res if res else '[FAILED]'}")
                    time.sleep(1)

        else:
            # Does not exist -> Create
            print(f" -> CREATE {disp_name} -> {wanted_ip}")
            if not args.dry_run:
                res = client.dns.add_dns_settings(
                    zone_host=ZONE_HOST,
                    record_type='A',
                    record_name=sub,
                    record_data=wanted_ip,
                    record_aux="0"
                )
                print(f"    {'[SUCCESS] ID: ' + res if res else '[FAILED]'}")
                time.sleep(1)

    print("-" * 60)
    print("Done.")

if __name__ == "__main__":
    main()
