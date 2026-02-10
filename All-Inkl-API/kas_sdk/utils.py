import os
import getpass
import keyring
from tabulate import tabulate

def get_kas_credentials():
    """
    Retrieves KAS credentials with the following priority:
    1. System Keyring (Service: 'kas_api')
    2. Environment Variables (KAS_LOGIN, KAS_PASS)
    3. Interactive Input (with option to save to Keyring)
    """
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

def print_table(data, headers, title=None):
    """
    Helper function to print list of dicts as a table using tabulate.
    """
    if not data:
        if title: print(f"{title}: None")
        return
    
    # Ensure data is a list of dicts
    if isinstance(data, dict):
        data = [data]
    
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
        print(f"{title}:")
    print(tabulate(table_data, headers=headers, tablefmt="simple"))
