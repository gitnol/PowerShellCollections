# Account & Session Management

## Table of Contents
*   [AccountService](#accountservice)
*   [SessionService](#sessionservice)

---

## AccountService
Found at `client.account`. Handles KAS sub-accounts.

### `get_accounts(account_login: str = None)`
List all accounts or a specific one.
```python
# List all
accounts = client.account.get_accounts()

# Get specific
acc = client.account.get_accounts(account_login="w0123456")
```

### `add_account(...)`
Create a new sub-account.
```python
client.account.add_account(
    account_kas_password="SecurePassword123!",
    account_ftp_password="FtpPassword123!",
    hostname_art="domain",       # 'domain', 'subdomain', or None
    hostname_part1="myshop",     # e.g. 'myshop'
    hostname_part2="example.com",# e.g. 'example.com'
    account_comment="Shop Account",
    max_account=1,
    max_domain=5,
    # ... many other optional parameters
)
```

### `update_account(...)`
Update account passwords or comments.
```python
client.account.update_account(
    account_login="w0123456",
    account_kas_password="NewPassword123!",
    account_comment="Updated Comment"
)
```

### `delete_account(account_login: str)`
Delete an account.
```python
client.account.delete_account(account_login="w0123456")
```

### `get_accountresources(account_login: str)`
Get resource usage for an account.
```python
res = client.account.get_accountresources("w0123456")
```

**Response Fields** — returns a dict where each key maps to a resource object:

| Key                | Sub-fields                                           |
|--------------------|------------------------------------------------------|
| `max_subdomain`    | `max`, `exceeded`, `reserved`, `created`, `used`     |
| `max_domain`       | `max`, `exceeded`, `reserved`, `created`, `used`     |
| `max_wbk`          | `max`, `exceeded`, `reserved`, `created`, `used`     |
| `max_ftpuser`      | `max`, `exceeded`, `reserved`, `created`, `used`     |
| `max_sambauser`    | `max`, `exceeded`, `reserved`, `created`, `used`     |
| `max_account`      | `max`, `exceeded`, `reserved`, `created`, `used`     |
| `max_webspace`     | `max`, `exceeded`, `reserved`, `created`, `used`     |
| `max_database`     | `max`, `exceeded`, `reserved`, `created`, `used`     |
| `max_mail_account` | `max`, `exceeded`, `reserved`, `created`, `used`     |
| `max_mail_forward` | `max`, `exceeded`, `reserved`, `created`, `used`     |
| `max_mailinglist`  | `max`, `exceeded`, `reserved`, `created`, `used`     |
| `max_cronjobs`     | `max`, `exceeded`, `reserved`, `created`, `used`     |

> A `max` value of `-1` means unlimited.

### `get_accountsettings(account_login: str)`
Get settings for an account.
```python
settings = client.account.get_accountsettings("w0123456")
```

### `update_accountsettings(...)`
Update specific account settings.
```python
client.account.update_accountsettings(
    account_login="w0123456",
    inst_htaccess="Y",
    logging="Y",
    show_password="N"
)
```

### `update_superusersettings(...)`
Update settings for a superuser.
```python
client.account.update_superusersettings(
    superuser_login="w0000000",
    kas_password="NewSuperPassword!"
)
```

### `get_server_information()`
Get host server info.
```python
info = client.account.get_server_information()
```

**Response Fields** — returns a list of dicts:

| Field              | Description                                |
|--------------------|--------------------------------------------|
| `service`          | Service type (`mysql`, `php`, `os`, `information`) |
| `version`          | Version string (e.g. `10.11.14`, `8.3`)    |
| `version_type`     | Version type (e.g. `server`)               |
| `interface`        | Interface type (e.g. `cgi-fcgi`)           |
| `file_extension`   | PHP file extension (e.g. `php83`)          |
| `distribution`     | OS distribution (e.g. `ubuntu`)            |
| `ipv4_address`     | Server IPv4 address                        |
| `server_name`      | Server hostname                            |

---

## SessionService
Found at `client.session`. Handles KAS SSO tokens.

### `add_session(session_lifetime: int = 1800, session_update_lifetime: str = "N")`
Create a session token for single-sign-on.
```python
token = client.session.add_session(
    session_lifetime=3600, 
    session_update_lifetime="Y"
)
# Use token in URL: https://kas.all-inkl.com/login.php?kas_login=w012345&session_id={token}
```
