"""
All-Inkl KAS DNS Optimization: Wildcard Removal
================================================
This script optimizes DNS zones by:
1. Identifying zones with Wildcard (*) A/AAAA records.
2. Creating explicit A/AAAA records for ALL active subdomains + 'www' (if missing).
3. VERIFYING that all required records exist.
4. Deleting the Wildcard record ONLY if verification passes.

SAFETY:
- Defaults to DRY-RUN mode. Use --execute to apply changes.
- Ensures 'www' and all KAS subdomains have explicit records before deleting *.
"""

import sys
import argparse
import time
from tabulate import tabulate
from kas_sdk import KasClient
from kas_sdk.utils import get_kas_credentials

def main():
    parser = argparse.ArgumentParser(description="KAS DNS Wildcard Removal Tool")
    parser.add_argument("--execute", action="store_true", help="Apply changes (DISABLE Dry-Run)")
    parser.add_argument("--domain", help="Target specific domain only (optional)")
    args = parser.parse_args()

    # 1. Get Credentials
    login, auth_data = get_kas_credentials()
    if not login or not auth_data:
        print("Error: Missing credentials. Exiting.")
        return

    # Initialize Client
    client = KasClient(kas_login=login, kas_auth_data=auth_data)

    print(f"--- KAS DNS Optimization (Mode: {'EXECUTE' if args.execute else 'DRY-RUN'}) ---")
    
    # Get Domains
    all_domains = client.domain.get_domains()
    if not all_domains:
        print("No domains found.")
        return

    # Filter if specific domain requested
    if args.domain:
        all_domains = [d for d in all_domains if d['domain_name'] == args.domain]

    print(f"Processing {len(all_domains)} domains...")

    for domain_obj in all_domains:
        domain = domain_obj['domain_name']
        print(f"Scanning {domain}...")

        try:
            # 1. Get current DNS Records
            records = client.dns.get_dns_settings(zone_host=domain)
            if not records:
                print("  No DNS records found.")
                continue
            
            # Identify Wildcards
            wildcards = [r for r in records if r['record_name'] == '*' and r['record_type'] in ('A', 'AAAA')]
            
            if not wildcards:
                print("  [OK] No wildcard records found.")
                continue

            print(f"  [WARN] Found {len(wildcards)} wildcard record(s).")
            
            # 2. Compile list of REQUIRED subdomains
            # a) All subdomains from KAS (account-wide list, filtered for this domain)
            all_subs = client.subdomain.get_subdomains()
            
            # Filter logic: subdomains belonging to current domain
            required_prefixes = set()
            
            # Always require 'www'
            required_prefixes.add("www")
            
            for s in all_subs:
                sub_name = s['subdomain_name']
                if sub_name == domain:
                    continue # Root domain, ignored here
                
                if sub_name.endswith(f".{domain}"):
                    # Extract prefix
                    prefix = sub_name.replace(f".{domain}", "")
                    if prefix:
                        required_prefixes.add(prefix)

            # Map existing DNS names
            existing_dns_names = set(r['record_name'] for r in records)

            # 3. Process Wildcard Replacements
            verification_needed = False

            for wc in wildcards:
                wc_type = wc['record_type']
                wc_target = wc['record_data']
                wc_id = wc['record_id']
                
                print(f"  Processing Wildcard: * ({wc_type}) -> {wc_target}")

                # Create explicit records where missing
                for prefix in required_prefixes:
                    if prefix in existing_dns_names:
                         # Already exists
                         pass
                    else:
                        print(f"    -> CREATE explicitly: {prefix} IN {wc_type} {wc_target}")
                        if args.execute:
                            client.dns.add_dns_settings(
                                zone_host=domain,
                                record_name=prefix,
                                record_type=wc_type,
                                record_data=wc_target,
                                record_aux="0" 
                            )
                            verification_needed = True
                            time.sleep(0.2) # Rate limit

                # 4. VERIFICATION STEP
                can_delete = True
                if args.execute:
                    print("    Running Verification...", end=" ")
                    if verification_needed:
                         # Re-fetch records to confirm existence
                         updated_records = client.dns.get_dns_settings(zone_host=domain)
                         updated_names = set(r['record_name'] for r in updated_records)
                    else:
                         updated_names = existing_dns_names

                    # Check if ALL required prefixes exist now
                    missing_after_update = [p for p in required_prefixes if p not in updated_names]
                    
                    if missing_after_update:
                        print(f"\n    [ERROR] Verification FAILED! Missing records: {missing_after_update}")
                        print("    [ABORT] Wildcard will NOT be deleted.")
                        can_delete = False
                    else:
                        print("[OK] All explicit records verified.")

                # 5. Delete Wildcard
                if can_delete:
                    print(f"    -> DELETE Wildcard: * IN {wc_type}")
                    if args.execute:
                        client.dns.delete_dns_settings(record_id=wc_id)
                        time.sleep(0.2)
                else:
                    print(f"    [SKIP] Wildcard delete skipped (Dry-Run or Verification Failed).")

        except Exception as e:
            print(f"  [ERROR] Failed processing {domain}: {e}")

    print("optimization complete.")

if __name__ == "__main__":
    main()
