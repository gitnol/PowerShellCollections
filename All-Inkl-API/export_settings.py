"""
All-Inkl KAS Configuration Export
=================================
Exports a complete configuration report of the KAS account to a Markdown file.

Covered Services:
- Account Data
- Domains & DNS Zones
- Subdomains
- Mail Accounts & Forwards & Lists
- Databases
- FTP Users
- Cronjobs
- Software Installations
- System Statistics (Space)
- DDNS Users
- Directory Protection

Output:
- Generates a file: `kas_export_YYYY-MM-DD_HHMM.md`
"""

import sys
import datetime
from tabulate import tabulate
from kas_sdk import KasClient
from kas_sdk.utils import get_kas_credentials

def fetch_data_safe(func, *args, **kwargs):
    """Helper to fetch data and handle potential API errors or empty results."""
    try:
        return func(*args, **kwargs)
    except Exception as e:
        return f"Error: {str(e)}"

def format_table(data, headers, title):
    """Formats a list of dicts as a Markdown table."""
    if not data:
        return f"\n### {title}\n*No data found.*\n"
    
    if isinstance(data, str) and "Error" in data:
         return f"\n### {title}\n> {data}\n"

    # Ensure list
    if isinstance(data, dict):
        data = [data]

    # Tabulate
    table_md = tabulate(
        [[item.get(h, "") for h in headers] for item in data],
        headers=headers,
        tablefmt="github"
    )
    
    return f"\n### {title}\n\n{table_md}\n"

def main():
    print("--- KAS Configuration Export ---")

    # 1. Credentials
    login, auth_data = get_kas_credentials()
    if not login or not auth_data:
        print("Error: Missing credentials.")
        return

    # 2. Initialize Client
    client = KasClient(kas_login=login, kas_auth_data=auth_data)

    # 3. Prepare Output File
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H%M")
    filename = f"kas_export_{timestamp}.md"
    
    print(f"Gathering data from KAS API (Account: {login})...")
    
    md_content = [
        f"# KAS Configuration Export",
        f"**Date**: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        f"**Account**: `{login}`",
        "\n---"
    ]

    # --- 1. Account & Stats ---
    print("-> Fetching Account & Stats...")
    account_data = fetch_data_safe(client.account.get_account_data)
    md_content.append(format_table(account_data, ["account_login", "account_tariff", "account_kas_password_last_change"], "Account Info"))

    space_data = fetch_data_safe(client.statistic.get_space)
    md_content.append(format_table(space_data, ["used_webspace", "max_webspace", "used_mailaccount_space"], "Space Usage"))

    # --- 2. Domains & DNS ---
    print("-> Fetching Domains & DNS...")
    domains = fetch_data_safe(client.domain.get_domains)
    md_content.append(format_table(domains, ["domain_name", "domain_path", "is_active"], "Domains"))
    
    if isinstance(domains, list):
        md_content.append("\n### DNS Zones (Detail)")
        for d in domains:
            d_name = d.get('domain_name')
            print(f"   -> DNS: {d_name}")
            dns_records = fetch_data_safe(client.dns.get_dns_settings, zone_host=d_name)
            if dns_records and not isinstance(dns_records, str):
                md_content.append(f"\n#### Zone: {d_name}")
                # Filter useful columns
                md_content.append(tabulate(
                    [[r.get('record_name'), r.get('record_type'), r.get('record_data'), r.get('record_aux')] for r in dns_records],
                    headers=["Name", "Type", "Data", "Aux"],
                    tablefmt="github"
                ))
            else:
                 md_content.append(f"\n#### Zone: {d_name}\n> No records or Error: {dns_records}")

    # --- 3. Subdomains ---
    print("-> Fetching Subdomains...")
    subs = fetch_data_safe(client.subdomain.get_subdomains)
    md_content.append(format_table(subs, ["subdomain_name", "subdomain_path"], "Subdomains"))

    # --- 4. Email ---
    print("-> Fetching Email Settings...")
    mails = fetch_data_safe(client.mailaccount.get_mailaccounts)
    md_content.append(format_table(mails, ["mail_login", "mail_address", "mail_comment"], "Mail Accounts"))

    forwards = fetch_data_safe(client.mailforward.get_mailforwards)
    md_content.append(format_table(forwards, ["mail_forward_source", "mail_forward_target"], "Mail Forwards"))

    lists = fetch_data_safe(client.mailinglist.get_mailinglists)
    md_content.append(format_table(lists, ["mailinglist_name", "mailinglist_comment"], "Mailing Lists"))

    # --- 5. Databases ---
    print("-> Fetching Databases...")
    dbs = fetch_data_safe(client.database.get_databases)
    md_content.append(format_table(dbs, ["database_login", "database_type", "database_comment"], "Databases"))

    # --- 6. FTP & Users ---
    print("-> Fetching FTP Users...")
    ftps = fetch_data_safe(client.ftpuser.get_ftpusers)
    md_content.append(format_table(ftps, ["ftp_login", "ftp_path", "ftp_comment"], "FTP Users"))

    # --- 7. Tools & Config ---
    print("-> Fetching Cronjobs & Tools...")
    crons = fetch_data_safe(client.cronjob.get_cronjobs)
    md_content.append(format_table(crons, ["cronjob_comment", "http_url", "schedule_minutes", "is_active"], "Cronjobs"))

    soft = fetch_data_safe(client.softwareinstall.get_softwareinstall)
    md_content.append(format_table(soft, ["software_name", "software_version", "domain_name"], "Software Installations"))

    ddns = fetch_data_safe(client.ddns.get_ddns_users)
    md_content.append(format_table(ddns, ["ddns_login", "ddns_remote_ip"], "DDNS Users"))

    # dir_protect = fetch_data_safe(client.directoryprotection.get_directoryprotection_users)
    # md_content.append(format_table(dir_protect, ["directory_protection_login", "directory_protection_path"], "Directory Protection"))

    # --- Write File ---
    print(f"Writing report to {filename}...")
    with open(filename, "w", encoding="utf-8") as f:
        f.write("\n".join(md_content))
    
    print("Done.")

if __name__ == "__main__":
    main()
