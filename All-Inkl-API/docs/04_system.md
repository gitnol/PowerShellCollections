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

### `add_database(...)`
Create a database.
```python
client.database.add_database(
    database_password="SecureDBPassword!",
    database_comment="App DB",
    database_ip="%"
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

### `add_ftpuser(...)`
Create FTP user.
```python
client.ftpuser.add_ftpuser(
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

### `get_softwareinstall(software_lang: str = "de")`
List available software packages.

### `add_softwareinstall(...)`
Install software.
```python
client.softwareinstall.add_softwareinstall(
    software_id="wordpress",
    domain_name="example.com",
    software_admin_mail="admin@example.com",
    software_database="d012345"
)
```

### `delete_softwareinstall(installation_id: str)`
Remove installation.

---

## StatisticService
Found at `client.statistic`.

- `get_space()`
- `get_traffic()`

---

## DirectoryProtectionService
Found at `client.directoryprotection`.

### `get_directoryprotection(directory_path: str = None)`
List protections.

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
Found at `client.sambauser`.
Manage network drive users.

- `add_sambauser(...)`
- `update_sambauser(...)`
- `delete_sambauser(...)`

---

## ChownService
Found at `client.chown`.

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

- `get_symlinks()`
- `add_symlink(source, target)`
- `delete_symlink(symlink_id)`
Create a MySQL database. User/Name is assigned automatically.
```python
db_name = client.database.add_database(
    database_password="SecureDbPass!",
    database_comment="Wordpress DB"
)
print(f"Created DB: {db_name}")
```

### `get_databases()`
```python
dbs = client.database.get_databases()
```

### `update_database(...)`
```python
client.database.update_database(
    database_login="w0123456_db1",
    database_password="NewPassword!"
)
```

### `delete_database(database_login)`
```python
client.database.delete_database("w0123456_db1")
```

---

## FtpUserService
Found at `client.ftpuser`.

### `get_ftpusers()`
List FTP users.
```python
users = client.ftpuser.get_ftpusers()
```

### `add_ftpusers(...)`
Create an FTP user.
```python
client.ftpuser.add_ftpusers(
    ftp_password="FtpPass2024!",
    ftp_comment="Dev Access",
    ftp_path="/www/dev",
    ftp_permission_read="Y",
    ftp_permission_write="Y"
)
```

### `update_ftpuser(...)`
```python
client.ftpuser.update_ftpuser(
    ftp_login="w0123456_f1",
    ftp_path="/www/new_path"
)
```

### `delete_ftpuser(ftp_login)`
```python
client.ftpuser.delete_ftpuser("w0123456_f1")
```

---

## SoftwareInstallService
Found at `client.softwareinstall`.

### `get_softwareinstall()`
List available installs (like WordPress).
```python
installs = client.softwareinstall.get_softwareinstall()
```

### `add_softwareinstall(...)`
Install a package.
```python
client.softwareinstall.add_softwareinstall(
    domain_name="example.com",
    software_id="wordpress_de",
    admin_mail="admin@example.com",
    database_update="N"
)
```

---

## StatisticService
Found at `client.statistic`.

### `get_space()`
Get disk usage.
```python
usage = client.statistic.get_space()
print(f"Used: {usage.get('used_space')} / {usage.get('available_space')}")
```

### `get_traffic()`
Get traffic usage.
```python
traffic = client.statistic.get_traffic()
```

---

## DirectoryProtectionService
Found at `client.directoryprotection`. Setup `.htaccess` auth.

### `get_directoryprotection()`
List protected directories.
```python
dirs = client.directoryprotection.get_directoryprotection()
```

### `add_directoryprotection(...)`
```python
client.directoryprotection.add_directoryprotection(
    directory_path="/www/secret",
    directory_user="admin",
    directory_password="AdminPassword!",
    directory_authname="Private Area"
)
```

### `update_directoryprotection(...)`
```python
client.directoryprotection.update_directoryprotection(
    directory_login="w012345_p1", # ID of protection
    directory_user="new_admin"
)
```

### `delete_directoryprotection(directory_login)`
```python
client.directoryprotection.delete_directoryprotection("w012345_p1")
```

---

## SambaUserService
Found at `client.sambauser`. Network storage access.

### `get_sambausers()`
List Samba users.
```python
users = client.sambauser.get_sambausers()
```

### `add_sambauser(...)`
```python
client.sambauser.add_sambauser(
    samba_path="/data/share",
    samba_login="office",
    samba_password="SharePassword!"
)
```

### `update_sambauser(...)`
```python
client.sambauser.update_sambauser(
    samba_login="office",
    samba_password="NewSharePassword!"
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
```python
client.chown.update_chown(
    chown_path="/www/wordpress",
    chown_user="w0123456",
    chown_recursive="Y"
)
```

---

## SymlinkService
Found at `client.symlink`.

### `get_symlinks()`
List symlinks.
```python
links = client.symlink.get_symlinks()
```

### `add_symlink(...)`
```python
client.symlink.add_symlink(
    symlink_source="/www/source",
    symlink_target="/www/link_name"
)
```

### `delete_symlink(symlink_id)`
```python
client.symlink.delete_symlink("123")
```
