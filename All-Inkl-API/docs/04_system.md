# System & Tools

## Table of Contents
*   [CronjobService](#cronjobservice)
*   [DatabaseService](#databaseservice)
*   [FtpUserService](#ftpuserservice)
*   [SoftwareInstallService](#softwareinstallservice)
*   [StatisticService](#statisticservice)
*   [DirectoryProtectionService](#directoryprotectionservice)
*   [SambaUserService](#sambauserservice)
*   [ChownService](#chownservice)
*   [SymlinkService](#symlinkservice)

---

## CronjobService
Found at `client.cronjob`. 

### `get_cronjobs(cronjob_id: int = None)`
List cronjobs.

### `add_cronjob(...)`
Add a new cronjob.
```python
client.cronjob.add_cronjob(
    protocol="http",
    http_url="http://example.com/cron.php",
    cronjob_comment="Main Cron",
    minute="*/5",
    hour="*",
    day_of_month="*",
    month="*",
    day_of_week="*",
    is_active="Y"
)
```

### `update_cronjob(...)`
Update cronjob settings.
```python
client.cronjob.update_cronjob(
    cronjob_id=123,
    minute="*/15"
)
```

### `delete_cronjob(cronjob_id: int)`
Delete a cronjob.

---

## DatabaseService
Found at `client.database`.

### `get_databases(database_login: str = None)`
List databases.
```python
dbs = client.database.get_databases()
```

**Response Fields** — returns a list of dicts:

| Field                    | Description                                |
|--------------------------|--------------------------------------------|
| `database_name`          | Database name                              |
| `database_login`         | Database login / username                  |
| `database_password`      | Password (masked in export)                |
| `database_comment`       | Comment                                    |
| `database_allowed_hosts` | Allowed hosts (e.g. `localhost`)           |
| `used_database_space`    | Disk space used (bytes)                    |

### `add_database(...)`
Create a database. User/Name is assigned automatically.
```python
client.database.add_database(
    database_password="SecureDBPassword!",
    database_comment="App DB",
    database_allowed_hosts="%"
)
```

### `update_database(...)`
Update database settings.
```python
client.database.update_database(
    database_login="d012345",
    database_new_password="NewPassword!"
)
```

### `delete_database(database_login: str)`
Delete a database.

---

## FtpUserService
Found at `client.ftpuser`.

### `get_ftpusers(ftp_login: str = None)`
List FTP users.
```python
users = client.ftpuser.get_ftpusers()
```

**Response Fields** — returns a list of dicts:

| Field                  | Description                                |
|------------------------|--------------------------------------------|
| `ftp_login`            | FTP login name                             |
| `ftp_password`         | Password (masked in export)                |
| `ftp_path`             | FTP root path                              |
| `ftp_comment`          | Comment                                    |
| `ftp_is_main_user`     | Main account user (`Y`/`N`)               |
| `ftp_permission_list`  | Can list directories (`Y`/`N`)             |
| `ftp_permission_write` | Can write (`Y`/`N`)                        |
| `ftp_permission_read`  | Can read (`Y`/`N`)                         |
| `ftp_virus_clamav`     | ClamAV virus scanning active (`Y`/`N`)     |
| `ftp_passwort`         | Password (plaintext, legacy field)         |
| `in_progress`          | Operation pending (`TRUE`/`FALSE`)         |

### `add_ftpusers(...)`
Create FTP user.
```python
client.ftpuser.add_ftpusers(
    ftp_password="FtpPassword!",
    ftp_comment="Dev User",
    ftp_path="/www/dev",
    ftp_permission_read="Y",
    ftp_permission_write="Y"
)
```

### `update_ftpuser(...)`
Update FTP user.
```python
client.ftpuser.update_ftpuser(
    ftp_login="f012345",
    ftp_new_password="NewFtpPassword!"
)
```

### `delete_ftpuser(ftp_login: str)`
Delete FTP user.

---

## SoftwareInstallService
Found at `client.softwareinstall`.

### `get_softwareinstall(software_id: str = None)`
List available software packages.
```python
installs = client.softwareinstall.get_softwareinstall()
```

**Response Fields** — returns a list of dicts:

| Field                             | Description                                      |
|-----------------------------------|--------------------------------------------------|
| `software_name`                   | Name (e.g. `WordPress`, `TYPO3`)                 |
| `software_category`              | Category (`CMS`, `Blog`, `Forum`, `Shop`, etc.)  |
| `software_has_example_data`       | Includes sample data (`Y`/`N`)                   |
| `software_version`                | Version string                                   |
| `software_licence`                | License URL                                      |
| `software_id`                     | Internal install ID                              |
| `software_version_php`            | Minimum PHP version                              |
| `software_version_php_upto`       | Maximum PHP version                              |
| `software_version_mysql`          | Minimum MySQL version                            |
| `software_version_mysql_upto`     | Maximum MySQL version                            |
| `software_version_mariadb`        | Minimum MariaDB version                          |
| `software_version_mariadb_upto`   | Maximum MariaDB version                          |

### `add_softwareinstall(...)`
Install software.
```python
client.softwareinstall.add_softwareinstall(
    software_id="wordpress",
    software_database="d012345",
    software_database_password="DBPassword!",
    software_hostname="example.com",
    software_path="/www/wordpress",
    software_admin_mail="admin@example.com",
    software_admin_user="admin",
    software_admin_pass="AdminPassword!",
    software_install_example_data="N",
    language="de"
)
```

### `delete_softwareinstall(installation_id: str)`
Remove installation.

---

## StatisticService
Found at `client.statistic`.

### `get_space(show_subaccounts: str = None, show_details: str = None)`
Get webspace usage.
```python
usage = client.statistic.get_space()

# With options
usage = client.statistic.get_space(show_subaccounts="Y", show_details="Y")
```

**Response Fields** — returns a list of dicts:

| Field                    | Description                                |
|--------------------------|--------------------------------------------|
| `account_login`          | Account login                              |
| `last_calculation`       | Unix timestamp of last calculation         |
| `used_htdocs_space`      | Web content disk usage (bytes)             |
| `used_chroot_space`      | Chroot disk usage (bytes)                  |
| `used_database_space`    | Database disk usage (bytes)                |
| `used_mailaccount_space` | Mailbox disk usage (bytes)                 |
| `used_webspace`          | Total webspace used (bytes)                |
| `max_webspace`           | Maximum webspace allowed (bytes)           |

### `get_space_usage(directory: str)`
Get usage for a specific directory.
```python
usage = client.statistic.get_space_usage("/www/example")
```

### `get_traffic(year: int = None, month: int = None)`
Get traffic usage.
```python
# Current month
traffic = client.statistic.get_traffic()

# Specific period
traffic = client.statistic.get_traffic(year=2026, month=1)
```

**Response Fields** — returns a list of dicts:

| Field            | Description                                    |
|------------------|------------------------------------------------|
| `account_login`  | Account login                                  |
| `year`           | Year                                           |
| `month`          | Month                                          |
| `http_traffic`   | HTTP traffic (bytes)                           |
| `ftp_traffic`    | FTP traffic (bytes)                            |
| `http_hits`      | Number of HTTP requests                        |
| `ftp_hits`       | Number of FTP requests                         |
| `comment`        | Summary label (e.g. `traffic summary for 2026-02`) |
| `day`            | Day of month (empty for monthly summary)       |

---

## DirectoryProtectionService
Found at `client.directoryprotection`. Setup `.htaccess` auth.

### `get_directoryprotection(directory_path: str = None)`
List protections.
```python
dirs = client.directoryprotection.get_directoryprotection()
```

**Response Fields** — returns a list of dicts:

| Field                | Description                              |
|----------------------|------------------------------------------|
| `directory_user`     | Auth username                            |
| `directory_path`     | Protected directory path                 |
| `directory_authname` | Auth realm name (e.g. `ByPassword`)      |
| `directory_password` | Password (masked in export)              |
| `in_progress`        | Operation pending (`TRUE`/`FALSE`)       |

### `add_directoryprotection(...)`
Add protection.
```python
client.directoryprotection.add_directoryprotection(
    directory_path="/www/secure",
    directory_user="admin",
    directory_password="password"
)
```

### `update_directoryprotection(...)`
Update protection. **Requires user+path as identifier.**
```python
client.directoryprotection.update_directoryprotection(
    directory_user="admin",
    directory_path="/www/secure",
    directory_new_password="NewPassword!"
)
```

### `delete_directoryprotection(...)`
Remove protection.
```python
client.directoryprotection.delete_directoryprotection(
    directory_user="admin",
    directory_path="/www/secure"
)
```

---

## SambaUserService
Found at `client.sambauser`. Manage network drive users.

### `get_sambausers(samba_login: str = None)`
List Samba users.
```python
users = client.sambauser.get_sambausers()

# Filter by login:
user = client.sambauser.get_sambausers(samba_login="office")
```

**Response Fields** — returns a list of dicts:

| Field            | Description                              |
|------------------|------------------------------------------|
| `samba_login`    | Samba login name                         |
| `samba_password` | Password (masked in export)              |
| `samba_path`     | Share path                               |
| `samba_comment`  | Comment                                  |
| `in_progress`    | Operation pending (`TRUE`/`FALSE`)       |

### `add_sambauser(samba_path: str, samba_new_password: str, samba_comment: str)`
All three parameters are required.
```python
client.sambauser.add_sambauser(
    samba_path="/data/share",
    samba_new_password="SharePassword!",
    samba_comment="Office Share"
)
```

### `update_sambauser(...)`
```python
client.sambauser.update_sambauser(
    samba_login="office",
    samba_new_password="NewSharePassword!",
    samba_comment="Updated Comment"
)
```

### `delete_sambauser(samba_login)`
```python
client.sambauser.delete_sambauser("office")
```

---

## ChownService
Found at `client.chown`. Reset file ownership permissions.

### `update_chown(...)`
Recursive owner fix.
```python
client.chown.update_chown(
    chown_path="/www/data",
    recursive="Y"
)
```

---

## SymlinkService
Found at `client.symlink`.

> [!WARNING]
> The `get_symlinks` action does **not** exist in the KAS API (returns `unkown_action`).
> Only `add_symlink` and `delete_symlink` are supported.

### `add_symlink(...)`
```python
client.symlink.add_symlink(
    symlink_name="/www/link_name",
    symlink_target="/www/source"
)
```

### `delete_symlink(symlink_id)`
```python
client.symlink.delete_symlink("123")
```
