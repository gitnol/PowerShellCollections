from kas_sdk import KasClient
import os

# Example Usage
# This script demonstrates how to use the modular All-Inkl KAS SDK

def main():
    # 1. Initialize Client
    client = KasClient(
        kas_login=os.environ.get('KAS_LOGIN', 'w0123456'),
        kas_auth_data=os.environ.get('KAS_PASS', 'secret'),
        kas_auth_type='plain',
        # dry_run=True  # Uncomment to test without sending requests
    )
    
    # You can also set the environment variable KAS_DRY_RUN=1 to enable dry-run globally.

    print("--- KAS SDK Example ---")

    try:
        # 2. Domain Service Example
        print("Fetching Domains...")
        domains = client.domain.get_domains()
        
        # Domains is now a list (from ReturnInfo) or empty list
        print(f"Found {len(domains)} domains.")
        if domains:
            for d in domains[:3]:
                 print(f"- {d.get('domain_name', 'Unknown')}")

        # 3. DNS Service Example (Handles Quirks safely)
        zone = "example.com"
        print(f"[DEMO] Adding DNS Record to {zone}...")
        
        # Note: Integers need to be strings where required, though some might be auto-converted if typed in SDK.
        # This will fail if credentials are fake, so we catch it.
        try:
            new_record_id = client.dns.add_dns_settings(
                zone_host=zone,          # SDK will append '.' -> "example.com."
                record_type="TXT",
                record_name="sdk-test",
                record_data="v=spf1 -all",
                record_aux="3600"        # Explicit string as per new strict typing
            )
            print(f"Created Record ID: {new_record_id}")

            if new_record_id and new_record_id != 'TRUE': 
                # 'TRUE' might be returned if no ID info, but usually it's the ID.
                # If it failed but returned a dict (error), it would be caught or handled.
                
                print(f"Updating Record {new_record_id}...")
                # Note: SDK knows NOT to send zone_host in update
                success = client.dns.update_dns_settings(
                    record_id=new_record_id,
                    record_data="v=spf1 mx -all"
                )
                print(f"Update successful: {success}")
        except Exception as api_err:
             print(f"API Call failed (Expected if using dummy creds): {api_err}")

        # 4. Other Services Demo
        print("--- Other Services ---")
        
        # Cronjobs
        print("Cronjobs:", len(client.cronjob.get_cronjobs()))
        
        # Databases
        dbs = client.database.get_databases()
        print(f"Databases: {len(dbs)}")
        
        # FTP Users
        ftp_users = client.ftpuser.get_ftpusers()
        print(f"FTP Users: {len(ftp_users)}")
        
        # Software Packages
        print("Software Packages:")
        packages = client.softwareinstall.get_softwareinstall()
        for pkg in packages[:3]:
             print(f"- {pkg.get('software_name')} (ID: {pkg.get('software_id')})")
        
        # System Stats
        print("Space Usage:", client.statistic.get_space())
        
        # Subdomains
        print("Subdomains:", len(client.subdomain.get_subdomains()))
        
        # DKIM (Check)
        # client.dkim.get_dkim(host="example.com")
        pass

    except Exception as e:
        print(f"General Error: {e}")

if __name__ == "__main__":
    main()
