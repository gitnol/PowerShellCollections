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
# Use token in URL: https://kas.all-inkl.com/kam/login.php?session_id={token}
```


### `get_accountresources(account_login)`
Get resource limits (space, traffic, etc).
```python
res = client.account.get_accountresources("w0123456")
```

### `get_accountsettings(account_login)`
Get account configuration.
```python
settings = client.account.get_accountsettings("w0123456")
```

### `update_accountsettings(...)`
Modify account settings (e.g. enable SSH).
```python
client.account.update_accountsettings(
    account_login="w0123456",
    ssh_access="Y"
)
```

### `update_superusersettings(...)`
Update settings for the logged-in superuser.
```python
client.account.update_superusersettings(
    superuser_login="w0123456",
    kas_password="NewSecureMasterPassword!"
)
```

### `get_server_information()`
Get host server info.
```python
info = client.account.get_server_information()
```

---

## SessionService
Found at `client.session`. Handles KAS SSO tokens.

### `add_session(...)`
Generate a session ID for Single Sign-On URL generation.
```python
session_id = client.session.add_session(
    session_lifetime=1800,       # 30 minutes
    session_update_lifetime="N"
)

# Usage: Construct URL
# https://kas.all-inkl.com/login.php?kas_login=w012345&session_id={session_id}
```
