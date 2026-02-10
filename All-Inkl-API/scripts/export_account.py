"""
All-Inkl KAS Configuration Export
=================================
Exports a complete configuration report of the KAS account to a Markdown file.
All response columns are detected dynamically from the API response data.

Covered Services (22 get methods):
- Account (accounts, resources, settings, server info)
- Domains & DNS Zones (with per-domain DNS detail)
- Subdomains
- Mail (accounts, forwards, lists, filters)
- Databases
- FTP Users
- Cronjobs
- Software Installations
- Statistics (space, traffic)
- DDNS Users
- Directory Protection
- Samba Users
- DKIM (per-domain)

Note: symlink service is excluded because the KAS API does not support
get_symlinks. Mail filters use get_mailstandardfilter (included).

Output:
- Generates a file: output/kas_export_YYYY-MM-DD_HHMM.md
"""

import datetime
import os
from tabulate import tabulate
from kas_sdk import KasClient
from kas_sdk.utils import get_kas_credentials


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

SENSITIVE_KEYWORDS = ("password", "passwd", "auth_data", "secret", "token")


def mask_value(key, value):
    """Mask sensitive values like passwords."""
    if any(kw in key.lower() for kw in SENSITIVE_KEYWORDS):
        return "***"
    return value


def truncate(value, max_len=80):
    """Truncate long values for readability."""
    s = str(value)
    if len(s) > max_len:
        return s[: max_len - 3] + "..."
    return s


def format_section(data, title, level=3):
    """
    Auto-detect columns from data and render as a Markdown table.
    Handles: list of dicts, single dict, empty data, error strings.
    """
    heading = "#" * level
    if not data:
        return f"{heading} {title}\n*No data found.*\n"

    if isinstance(data, str):
        return f"{heading} {title}\n> {data}\n"

    # Single dict -> key/value list (vertical layout)
    if isinstance(data, dict):
        rows = [[k, truncate(mask_value(k, v))] for k, v in data.items()]
        table = tabulate(rows, headers=["Key", "Value"], tablefmt="github")
        return f"{heading} {title}\n\n{table}\n"

    # List of dicts -> horizontal table with auto-detected headers
    if isinstance(data, list) and len(data) > 0:
        # Collect ALL keys across all records (union)
        all_keys = []
        seen = set()
        for item in data:
            if isinstance(item, dict):
                for k in item.keys():
                    if k not in seen:
                        all_keys.append(k)
                        seen.add(k)

        if not all_keys:
            return f"{heading} {title}\n*Unexpected data format.*\n"

        rows = []
        for item in data:
            if isinstance(item, dict):
                rows.append(
                    [truncate(mask_value(k, item.get(k, ""))) for k in all_keys]
                )
            else:
                rows.append([truncate(str(item))])

        table = tabulate(rows, headers=all_keys, tablefmt="github")
        return f"{heading} {title}\n\n{table}\n"

    # Fallback
    return f"{heading} {title}\n```\n{data}\n```\n"


def fetch_safe(label, func, *args, **kwargs):
    """Fetch data safely, printing progress and catching errors."""
    print(f"  -> {label}...")
    try:
        result = func(*args, **kwargs)
        if result:
            count = len(result) if isinstance(result, (list, dict)) else "?"
            print(f"     OK ({count} entries)")
        else:
            print("     OK (empty)")
        return result
    except Exception as e:
        print(f"     ERROR: {e}")
        return f"Error: {e}"


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    print("=== KAS Configuration Export ===")

    # 1. Credentials
    login, auth_data = get_kas_credentials()
    if not login or not auth_data:
        print("Error: Missing credentials.")
        return

    client = KasClient(kas_login=login, kas_auth_data=auth_data)

    timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H%M")
    output_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "output")
    os.makedirs(output_dir, exist_ok=True)
    filename = os.path.join(output_dir, f"kas_export_{timestamp}.md")
    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    print(f"Account: {login}")
    print(f"Output:  {filename}")
    print("Gathering data...")

    md = []
    md.append(f"# KAS Configuration Export")
    md.append(f"**Date**: {now_str}  ")
    md.append(f"**Account**: `{login}`")
    md.append("")
    md.append("---")
    md.append("")

    # -----------------------------------------------------------------------
    # 1. ACCOUNT
    # -----------------------------------------------------------------------
    md.append("## 1. Account & Server")
    md.append("")

    data = fetch_safe("Accounts", client.account.get_accounts)
    md.append(format_section(data, "Accounts"))

    data = fetch_safe("Account Resources", client.account.get_accountresources)
    md.append(format_section(data, "Account Resources"))

    data = fetch_safe("Account Settings", client.account.get_accountsettings)
    md.append(format_section(data, "Account Settings"))

    data = fetch_safe("Server Information", client.account.get_server_information)
    md.append(format_section(data, "Server Information"))

    # -----------------------------------------------------------------------
    # 2. DOMAINS & DNS
    # -----------------------------------------------------------------------
    md.append("## 2. Domains & DNS")
    md.append("")

    domains = fetch_safe("Domains", client.domain.get_domains)
    md.append(format_section(domains, "Domains"))

    tlds = fetch_safe("Top-Level Domains", client.domain.get_topleveldomains)
    md.append(format_section(tlds, "Available TLDs"))

    # Per-domain: DNS + DKIM
    if isinstance(domains, list):
        md.append("### DNS Zones (Detail)")
        md.append("")
        for d in domains:
            d_name = d.get("domain_name", "?")
            dns_data = fetch_safe(f"DNS: {d_name}", client.dns.get_dns_settings, zone_host=d_name)
            md.append(format_section(dns_data, f"Zone: {d_name}", level=4))

        md.append("### DKIM (Detail)")
        md.append("")
        for d in domains:
            d_name = d.get("domain_name", "?")
            dkim_data = fetch_safe(f"DKIM: {d_name}", client.dkim.get_dkim, host=d_name)
            md.append(format_section(dkim_data, f"DKIM: {d_name}", level=4))

    # -----------------------------------------------------------------------
    # 3. SUBDOMAINS
    # -----------------------------------------------------------------------
    md.append("## 3. Subdomains")
    md.append("")

    data = fetch_safe("Subdomains", client.subdomain.get_subdomains)
    md.append(format_section(data, "Subdomains"))

    # -----------------------------------------------------------------------
    # 4. EMAIL
    # -----------------------------------------------------------------------
    md.append("## 4. Email")
    md.append("")

    data = fetch_safe("Mail Accounts", client.mailaccount.get_mailaccounts)
    md.append(format_section(data, "Mail Accounts"))

    data = fetch_safe("Mail Forwards", client.mailforward.get_mailforwards)
    md.append(format_section(data, "Mail Forwards"))

    data = fetch_safe("Mailing Lists", client.mailinglist.get_mailinglists)
    md.append(format_section(data, "Mailing Lists"))

    data = fetch_safe("Mail Filters", client.mailfilter.get_mailstandardfilter)
    md.append(format_section(data, "Mail Filters"))

    # -----------------------------------------------------------------------
    # 5. DATABASES
    # -----------------------------------------------------------------------
    md.append("## 5. Databases")
    md.append("")

    data = fetch_safe("Databases", client.database.get_databases)
    md.append(format_section(data, "Databases"))

    # -----------------------------------------------------------------------
    # 6. FTP
    # -----------------------------------------------------------------------
    md.append("## 6. FTP Users")
    md.append("")

    data = fetch_safe("FTP Users", client.ftpuser.get_ftpusers)
    md.append(format_section(data, "FTP Users"))

    # -----------------------------------------------------------------------
    # 7. CRONJOBS
    # -----------------------------------------------------------------------
    md.append("## 7. Cronjobs")
    md.append("")

    data = fetch_safe("Cronjobs", client.cronjob.get_cronjobs)
    md.append(format_section(data, "Cronjobs"))

    # -----------------------------------------------------------------------
    # 8. SOFTWARE
    # -----------------------------------------------------------------------
    md.append("## 8. Software Installations")
    md.append("")

    data = fetch_safe("Software", client.softwareinstall.get_softwareinstall)
    md.append(format_section(data, "Software Installations"))

    # -----------------------------------------------------------------------
    # 9. STATISTICS
    # -----------------------------------------------------------------------
    md.append("## 9. Statistics")
    md.append("")

    data = fetch_safe("Space Usage", client.statistic.get_space)
    md.append(format_section(data, "Space Usage"))

    data = fetch_safe("Traffic", client.statistic.get_traffic)
    md.append(format_section(data, "Traffic"))

    # -----------------------------------------------------------------------
    # 10. NETWORK & SECURITY
    # -----------------------------------------------------------------------
    md.append("## 10. Network & Security")
    md.append("")

    data = fetch_safe("DDNS Users", client.ddns.get_ddnsusers)
    md.append(format_section(data, "DDNS Users"))

    data = fetch_safe("Directory Protection", client.directoryprotection.get_directoryprotection)
    md.append(format_section(data, "Directory Protection"))

    data = fetch_safe("Samba Users", client.sambauser.get_sambausers)
    md.append(format_section(data, "Samba Users"))

    # NOTE: get_symlinks does not exist in the KAS API (returns unkown_action)
    # data = fetch_safe("Symlinks", client.symlink.get_symlinks)
    # md.append(format_section(data, "Symlinks"))

    # -----------------------------------------------------------------------
    # FOOTER
    # -----------------------------------------------------------------------
    md.append("---")
    md.append(f"*Generated by `export_settings.py` on {now_str}*")

    # Write file
    print(f"Writing report to {filename}...")
    with open(filename, "w", encoding="utf-8") as f:
        f.write("\n".join(md))

    print(f"Done! Report saved to: {filename}")


if __name__ == "__main__":
    main()
