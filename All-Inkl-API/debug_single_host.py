import os
import sys
from kas_sdk import KasClient

def main():
    kas_login = os.environ.get('KAS_LOGIN')
    kas_pass = os.environ.get('KAS_PASS')
    kas_auth_type = os.environ.get('KAS_AUTH_TYPE', 'plain')

    target_host = "myhost.mydomain.com"

    print(f"--- Debugging Single Host: {target_host} ---")
    client = KasClient(kas_login=kas_login, kas_auth_data=kas_pass, kas_auth_type=kas_auth_type)

    print("Requesting get_subdomains(subdomain_name=...)")
    try:
        # SDK get_subdomains handles string param as subdomain_name
        # based on subdomain.py: def get_subdomains(self, subdomain_name: str = None)
        subdomains = client.subdomain.get_subdomains(subdomain_name=target_host)
        
        print(f"Result type: {type(subdomains)}")
        print(f"Result len: {len(subdomains)}")
        
        if subdomains:
            item = subdomains[0]
            print("Keys found:")
            print(list(item.keys()))
            
            print("SSL Values:")
            ssl_debug = {k:v for k,v in item.items() if 'ssl' in k}
            print(ssl_debug)
            
            # Check specifically for the 'j'/'Y' values user mentioned
            print(f"ssl_certificate_sni_is_active: {item.get('ssl_certificate_sni_is_active')}")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
