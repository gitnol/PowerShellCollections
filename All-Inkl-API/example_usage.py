from kas_sdk import KasClient
import os

# Example Usage
# This script demonstrates how to use the modular All-Inkl KAS SDK

import keyring
import getpass

# Helper to manage credentials securely
def get_kas_credentials():
    """
    Retrieves KAS credentials with the following priority:
    1. System Keyring (Service: 'kas_api')
    2. Environment Variables (KAS_LOGIN, KAS_PASS)
    3. Interactive Input (with option to save to Keyring)
    """
    service_id = "kas_api"
    
    service_id = "kas_api"
    default_login_key = "default_kas_login"
    
    # 1. Try Environment Variable for Login
    kas_login = os.environ.get('KAS_LOGIN')
    kas_auth_data = None
    
    # 2. Try Keyring for Default Login (if Env not set)
    if not kas_login:
        kas_login = keyring.get_password(service_id, default_login_key)
        if kas_login:
             print(f"Loaded default login '{kas_login}' from System Keyring.")
    
    # 3. Try Keyring for Password (if Login known)
    if kas_login:
        kas_auth_data = keyring.get_password(service_id, kas_login)
        if kas_auth_data:
            print(f"Loaded credentials for '{kas_login}' from System Keyring.")
            return kas_login, kas_auth_data

    # 4. Try Env Vars for Password (if Keyring failed)
    if not kas_auth_data:
        kas_auth_data = os.environ.get('KAS_PASS')
        if kas_login and kas_auth_data:
             print(f"Loaded credentials for '{kas_login}' from Environment Variables.")
             return kas_login, kas_auth_data

    # 5. Interactive Input
    print("--- KAS API Credentials Setup ---")
    if kas_login:
        print(f"Using Login: {kas_login}")
    else:
        print("No credentials found in Keyring or Environment.")
    
    if not kas_login:
        kas_login = input("Enter KAS Login (e.g. w012345): ").strip()
        
        # RETRY KEYRING: Maybe password exists for this manually entered login?
        if kas_login:
            kas_auth_data = keyring.get_password(service_id, kas_login)
            if kas_auth_data:
                print(f"Found saved password for '{kas_login}'!")
                return kas_login, kas_auth_data
    
    if not kas_auth_data:
        kas_auth_data = getpass.getpass(f"Enter KAS Password for {kas_login}: ").strip()
    
    # Offer to save credentials
    if kas_login and kas_auth_data:
        save = input("Save credentials to System Keyring for future use? (y/n): ").lower()
        if save == 'y':
            # Save Password
            keyring.set_password(service_id, kas_login, kas_auth_data)
            # Save Login as Default
            keyring.set_password(service_id, default_login_key, kas_login)
            print("Credentials saved to System Keyring!")

    return kas_login, kas_auth_data

def get_dry_run_preference():
    """
    Retrieves Dry Run preference (True/False) from:
    1. Environment Variable (KAS_DRY_RUN)
    2. System Keyring (Service: 'kas_api', User: 'config_dry_run')
    3. Interactive Input (with option to save)
    """
    service_id = "kas_api"
    config_user = "config_dry_run"
    
    # 1. Env Var
    env_val = os.environ.get('KAS_DRY_RUN')
    if env_val:
        return env_val.lower() in ('true', '1', 'yes')
        
    # 2. Keyring
    stored_val = keyring.get_password(service_id, config_user)
    if stored_val is not None:
        return stored_val == "1"
        
    # 3. Interactive
    print("--- Configuration Setup ---")
    choice = input("Enable DRY-RUN mode? (No API calls will be sent) (y/n): ").lower()
    is_dry_run = choice == 'y'
    
    save = input("Save this preference to System Keyring? (y/n): ").lower()
    if save == 'y':
        # Store "1" for True, "0" for False
        keyring.set_password(service_id, config_user, "1" if is_dry_run else "0")
        print("Preference saved to System Keyring!")
        
    return is_dry_run

def main():
    # 1. Get Credentials & Config
    login, auth_data = get_kas_credentials()
    
    if not login or not auth_data:
        print("Error: Missing credentials. Exiting.")
        return
        
    is_dry_run = get_dry_run_preference()

    # 2. Initialize Client
    client = KasClient(
        kas_login=login,
        kas_auth_data=auth_data,
        kas_auth_type='plain',
        dry_run=is_dry_run
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
        print("--- DNS Demo ---")
        zone = input("Enter Zone (Domain) to add record to (leave empty to skip): ").strip()
        
        if zone:
            print(f"[DEMO] Checking DNS Records for {zone}...")
            
            # Note: Integers need to be strings where required, though some might be auto-converted if typed in SDK.
            try:
                # 1. Check if record exists
                existing_records = client.dns.get_dns_settings(zone_host=zone)
                target_record = None
                
                # Check if we get a list or single dict
                if isinstance(existing_records, dict):
                    existing_records = [existing_records]
                
                for rec in existing_records:
                     if rec.get('record_name') == 'sdk-test' and rec.get('record_type') == 'TXT':
                         target_record = rec
                         break
                
                record_id_to_update = None

                if target_record:
                    print(f"Record 'sdk-test' already exists (ID: {target_record.get('record_id')}).")
                    record_id_to_update = target_record.get('record_id')
                else:
                    print(f"Creating new DNS Record for {zone}...")
                    new_record_id = client.dns.add_dns_settings(
                        zone_host=zone,          # SDK will append '.' -> "example.com."
                        record_type="TXT",
                        record_name="sdk-test",
                        record_data="v=spf1 -all",
                        record_aux="0"           # TXT records usually have aux=0
                    )
                    print(f"Created Record ID: {new_record_id}")
                    record_id_to_update = new_record_id

                if record_id_to_update and record_id_to_update != 'TRUE': 
                    # 'TRUE' might be returned if no ID info, but usually it's the ID.
                    
                    print(f"Updating Record {record_id_to_update}...")
                    # Note: SDK knows NOT to send zone_host in update
                    success = client.dns.update_dns_settings(
                        record_id=record_id_to_update,
                        record_data="v=spf1 mx -all"
                    )
                    print(f"Update successful: {success}")
                    
            except Exception as api_err:
                 error_msg = str(api_err)
                 if "nothing_to_do" in error_msg:
                     print("Update check: Data is identical (nothing to do). This is expected.")
                 else:
                     print(f"API Call failed (Expected if using dummy creds): {api_err}")
        else:
            print("Skipping DNS Demo.")

        # 4. Other Services Demo
        print("--- Other Services ---")
        
        from tabulate import tabulate

        def print_table(data, headers, title=None):
            if not data:
                if title: print(f"{title}: None")
                return
            
            # Ensure data is a list of dicts
            if isinstance(data, dict):
                data = [data]
            
            # Extract only requested headers if creating from dict list
            # Or just let tabulate handle list of lists
            
            # Auto-detect headers if not provided? 
            # Better to be explicit for cleaner output
            
            table_data = []
            for item in data:
                row = []
                for h in headers:
                    val = item.get(h, "")
                    # Truncate long values
                    if len(str(val)) > 50:
                        val = str(val)[:47] + "..."
                    row.append(val)
                table_data.append(row)

            if title:
                print(f"\n{title}:")
            print(tabulate(table_data, headers=headers, tablefmt="simple"))

        # Cronjobs
        cronjobs = client.cronjob.get_cronjobs()
        print_table(cronjobs, 
                    headers=["cronjob_id", "cronjob_comment", "http_url", "is_active"], 
                    title="Cronjobs")
        
        # Databases
        dbs = client.database.get_databases()
        print_table(dbs, 
                    headers=["database_login", "database_comment", "database_type"], 
                    title="Databases")
        
        # FTP Users
        ftp_users = client.ftpuser.get_ftpusers()
        print_table(ftp_users, 
                    headers=["ftp_login", "ftp_path", "ftp_comment"], 
                    title="FTP Users")
        
        # Software Packages
        packages = client.softwareinstall.get_softwareinstall()
        # Limit to 5 for brevity in demo
        if packages and isinstance(packages, list):
             packages = packages[:5]
        
        print_table(packages, 
                    headers=["software_id", "software_name", "software_version", "domain_name"], 
                    title="Software Packages (Top 5)")
        
        # System Stats
        space = client.statistic.get_space()
        if space:
             # Space might be a list of accounts or a single dict
             if isinstance(space, dict):
                 space = [space]
            
             print_table(space, 
                        headers=["used_webspace", "max_webspace", "used_mailaccount_space"], 
                        title="Space Usage")
        
        # Subdomains
        subs = client.subdomain.get_subdomains()
        # Limit 
        if subs and isinstance(subs, list):
             subs = subs[:10]
        print_table(subs, 
                    headers=["subdomain_name", "subdomain_path"], 
                    title="Subdomains (Top 10)")
        
        # DKIM (Check)
        # client.dkim.get_dkim(host="example.com")
        pass

    except Exception as e:
        print(f"General Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
