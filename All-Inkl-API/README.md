# All-Inkl KAS SOAP API SDK for Python

A robust, modular Python SDK for the All-Inkl KAS SOAP API.  
It handles known API quirks (like integer handling and trailing dots) automatically, so you don't have to.

## Features

- **Automatic Type Conversion**: Converts integers to strings (API requirement).
- **DNS Safeties**: 
    - Auto-appends trailing dots for `zone_host` on creation.
    - Strips `zone_host` on updates (prevents errors).
- **Recursive XML Parsing**: Properly handles complex nested responses and lists.
- **Service Pattern**: Organized modules for `Account`, `DNS`, `Domain`, and `Mail`.
- **Flood Protection**: Build-in rate limiting (defaults to 2s).

## Installation

Allow the package to be imported by placing the `kas_sdk` folder in your project root or `PYTHONPATH`.

## Usage

### Credential Management (Secure)

The SDK supports secure credential management via **Keyring** (System Vault) and **Environment Variables**, so you don't have to hardcode passwords in scripts.

**Priority Order:**
1.  **Explicit Arguments**: Passed directly to `KasClient`.
2.  **Environment Variables**: `KAS_LOGIN` and `KAS_PASS`.
3.  **System Keyring**: Looks for service `kas_api` and your login user.

### Initialization

```python
from kas_sdk import KasClient

# 1. Automatic Discovery (Recommended)
# Looks in Env Vars or Keyring
client = KasClient(kas_login='w0123456') 

# 2. Hardcoded (Not Recommended)
client = KasClient('w0123456', 'secret_password')

# 3. Dry Run Config
# client = KasClient(dry_run=True)
```

### Dry Run Mode

You can enable `dry_run` mode to simulate requests without sending them to the API. This is useful for testing and debugging.

- **Constructor**: Pass `dry_run=True` to the `KasClient` constructor.
- **Environment Variable**: Set `KAS_DRY_RUN=1` (or `true`) in your environment.

When enabled, the client will log the request details (Action, Params, XML) and return a mock success response.


### API Coverage Status

The following table lists the KAS API functions and their implementation status in this SDK.

## Documentation

The API Documentation is split into logical sections for easier navigation.

### 📚 [1. Account & Session Management](docs/01_account.md)
*   **AccountService**: Create and manage KAS sub-accounts and settings.
*   **SessionService**: Generate KAS SSO tokens.

### 🌐 [2. Domains & DNS](docs/02_domains_dns.md)
*   **DomainService**: Add/Move/Delete domains.
*   **SubdomainService**: Manage subdomains.
*   **DnsService**: Edit zone records (A, MX, TXT, etc).
*   **DdnsService**: Manage DynDNS users.
*   **SslService**: Manage Let's Encrypt certificates.

### 📧 [3. Email Infrastructure](docs/03_email.md)
*   **MailAccountService**: Manage POP3/IMAP mailboxes.
*   **MailForwardService**: Setup email forwarders.
*   **MailFilterService**: Configure server-side rules.
*   **MailingListService**: Manage mailing lists.

### 🛠️ [4. System & Tools](docs/04_system.md)
*   **CronjobService**: Manage strict cronjobs.
*   **DatabaseService**: Create MySQL databases.
*   **FtpUserService**: Manage FTP access.
*   **SoftwareInstallService**: Application installers (e.g. WordPress).
*   **StatisticService**: Check disk space and traffic.
*   **DirectoryProtectionService**: htaccess protection.
*   **Samba/Chown/Symlink**: Advanced filesystem tools.

## Supported Services Overview

Here is a quick summary of available services on the `KasClient`:

| Service Property | Class | Key Functions |
| :--- | :--- | :--- |
| `client.account` | `AccountService` | `get_accounts`, `add_account`... |
| `client.dns` | `DnsService` | `get_dns_settings`, `add_record`... |
| `client.domain` | `DomainService` | `get_domains`, `add_domain`... |
| `client.mailaccount` | `MailAccountService` | `get_mailaccounts`... |
| `client.cronjob` | `CronjobService` | `get_cronjobs`, `add_cronjob`... |
| `client.database` | `DatabaseService` | `get_databases`, `add_database`... |
| `client.ftpuser` | `FtpUserService` | `get_ftpusers`, `add_ftpusers`... |
| `client.dkim` | `DkimService` | `get_dkim`, `add_dkim`, `delete_dkim`... |
| *(See detailed docs above for full list)* | | |


## Running Tests

You can run the included verification script to check payload construction without actual API credentials:

```bash
python verify_payloads.py
```
