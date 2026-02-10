# Domains & DNS Management

## Table of Contents
*   [DomainService](#domainservice)
*   [SubdomainService](#subdomainservice)
*   [DnsService](#dnsservice)
*   [DdnsService](#ddnsservice)
*   [SslService](#sslservice)

---

## DomainService
Found at `client.domain`.

### `get_domains(domain_name: str = None)`
List domains.
```python
domains = client.domain.get_domains()
```

**Response Fields** — returns a list of dicts:

| Field                               | Description                                    |
|--------------------------------------|------------------------------------------------|
| `domain_name`                        | Domain name                                    |
| `domain_redirect_status`             | HTTP redirect code (`0` = no redirect, `301`)  |
| `domain_path`                        | Target path or redirect URL                    |
| `dummy_host`                         | Whether this is a dummy host (`Y`/`N`)         |
| `fpse_active`                        | FrontPage extensions active (`Y`/`N`)          |
| `dkim_selector`                      | Active DKIM selector                           |
| `statistic_language`                 | Statistics language (`de`, `en`)                |
| `statistic_version`                  | Statistics version (e.g. `4`, `5`)             |
| `ssl_proxy`                          | SSL proxy active (`Y`/`N`)                     |
| `ssl_certificate_ip`                 | IP-based SSL certificate (`Y`/`N`)             |
| `ssl_certificate_sni`                | SNI SSL certificate (`Y`/`N`)                  |
| `ssl_certificate_sni_is_active`      | SNI cert currently active (`j`/`n`)            |
| `ssl_certificate_sni_type`           | Certificate type (e.g. `unknown`)              |
| `ssl_certificate_sni_force_https`    | Force HTTPS redirect                           |
| `ssl_certificate_sni_hsts_max_age`   | HSTS max-age value                             |
| `php_version`                        | Active PHP version (e.g. `8.3`)                |
| `php_deprecated`                     | PHP version deprecated (`Y`/`N`)               |
| `is_active`                          | Domain active (`Y`/`N`)                        |
| `in_progress`                        | Operation pending (`TRUE`/`FALSE`)             |

### `add_domain(...)`
Add a domain to the account.
```python
client.domain.add_domain(
    domain_name="new-example.com",
    domain_tld="com",
    domain_path="/www/new-example",
    redirect_status=301
)
```

### `update_domain(...)`
Modify domain settings (e.g. path).
```python
client.domain.update_domain(
    domain_name="new-example.com",
    domain_path="/www/updated_path",
    is_active="Y"
)
```

### `delete_domain(domain_name: str)`
Remove a domain.
```python
client.domain.delete_domain("new-example.com")
```

### `move_domain(...)`
Move domain to another customer (sub-account).
```python
client.domain.move_domain(
    domain_name="example.com",
    source_account="w0123456",
    target_account="w0987654"
)
```

### `get_topleveldomains()`
List available TLDs.
```python
tlds = client.domain.get_topleveldomains()
```

**Response Fields** — returns a list of dicts:

| Field        | Description                        |
|--------------|------------------------------------|
| `tld_name`   | TLD string (e.g. `de`, `com`)      |
| `tld_minlen` | Minimum label length               |
| `tld_maxlen` | Maximum label length               |

---

## SubdomainService
Found at `client.subdomain`.

### `get_subdomains(subdomain_name: str = None)`
List subdomains.
```python
subs = client.subdomain.get_subdomains()
```

**Response Fields** — returns a list of dicts:

| Field                               | Description                                    |
|--------------------------------------|------------------------------------------------|
| `subdomain_name`                     | Full subdomain name                            |
| `subdomain_redirect_status`          | HTTP redirect code (`0` = no redirect)         |
| `subdomain_path`                     | Target path or redirect URL                    |
| `subdomain_account`                  | Owning account login                           |
| `subdomain_server`                   | Server hostname                                |
| `ssl_proxy`                          | SSL proxy active (`Y`/`N`)                     |
| `ssl_certificate_sni`                | SNI SSL certificate (`Y`/`N`)                  |
| `ssl_certificate_sni_is_active`      | SNI cert active (`j`/`n`)                      |
| `ssl_certificate_sni_type`           | Certificate type                               |
| `ssl_certificate_sni_force_https`    | Force HTTPS redirect                           |
| `ssl_certificate_sni_hsts_max_age`   | HSTS max-age value                             |
| `fpse_active`                        | FrontPage extensions active (`Y`/`N`)          |
| `statistic_version`                  | Statistics version                             |
| `statistic_language`                 | Statistics language                            |
| `php_version`                        | Active PHP version                             |
| `php_deprecated`                     | PHP version deprecated (`Y`/`N`)               |
| `is_active`                          | Subdomain active (`Y`/`N`)                     |
| `in_progress`                        | Operation pending (`TRUE`/`FALSE`)             |

### `add_subdomain(...)`
Create a subdomain.
```python
client.subdomain.add_subdomain(
    subdomain_name="shop",
    domain_name="example.com",
    subdomain_path="/www/shop",
    redirect_status=0,
    statistic_language="de",
    php_version="8.2"
)
```

### `update_subdomain(...)`
Update subdomain path or redirect.
```python
client.subdomain.update_subdomain(
    subdomain_name="shop.example.com",
    subdomain_path="/new/path",
    php_version="8.2"
)
```

### `delete_subdomain(subdomain_name: str)`
Delete a subdomain.
```python
client.subdomain.delete_subdomain("shop.example.com")
```

---

## DnsService
Found at `client.dns`.

### `get_dns_settings(zone_host: str, record_id: str = None)`
List DNS records for a zone.
```python
records = client.dns.get_dns_settings(zone_host="example.com")
```

**Response Fields** — returns a list of dicts:

| Field               | Description                              |
|---------------------|------------------------------------------|
| `record_zone`       | Zone hostname                            |
| `record_name`       | Record name (subdomain part)             |
| `record_type`       | Record type (`A`, `MX`, `NS`, `TXT`, `CNAME`, `SRV`) |
| `record_data`       | Record value / target                    |
| `record_aux`        | Auxiliary value (e.g. MX priority)       |
| `record_id`         | Record ID (0 = system-managed)           |
| `record_changeable` | Can be edited (`Y`/`N`)                  |
| `record_deleteable` | Can be deleted (`Y`/`N`)                 |

### `add_dns_settings(...)`
Add a DNS record.
```python
client.dns.add_dns_settings(
    zone_host="example.com",
    record_type="A",
    record_name="sub",       # sub.example.com
    record_data="1.2.3.4",
    record_aux="0"
)
```

### `update_dns_settings(...)`
Update a DNS record.
```python
client.dns.update_dns_settings(
    record_id="12345",
    record_data="5.6.7.8"
)
```

### `delete_dns_settings(record_id: str)`
Delete a record.
```python
client.dns.delete_dns_settings("12345")
```

### `reset_dns_settings(zone_host: str, nameserver: str)`
Reset zone to default.
```python
client.dns.reset_dns_settings(zone_host="example.com")
```

---

## DdnsService
Found at `client.ddns`.

### `get_ddnsusers(ddns_login: str = None)`
List DynDNS users.
```python
users = client.ddns.get_ddnsusers()
```

### `add_ddnsuser(...)`
Create a DynDNS user. All parameters are required.
```python
client.ddns.add_ddnsuser(
    dyndns_comment="Home DDNS",
    dyndns_password="SecretPassword!",
    dyndns_zone="example.com",
    dyndns_label="home",
    dyndns_target_ip="1.2.3.4"
)
```

### `update_ddnsuser(...)`
Update DynDNS user password or comment.
```python
client.ddns.update_ddnsuser(
    dyndns_login="dy12345",
    dyndns_password="NewPassword!"
)
```

### `delete_ddnsuser(dyndns_login: str)`
Delete DynDNS user.

---

## SslService
Found at `client.ssl`. Manage SSL certificates for a hostname.

### `update_ssl(...)`
Update SSL settings for a hostname.
```python
# Enable SSL and force HTTPS with HSTS
client.ssl.update_ssl(
    hostname="example.com",
    ssl_certificate_is_active="Y",
    ssl_certificate_force_https="Y",
    ssl_certificate_hsts_max_age=31536000
)

# Upload a custom certificate
client.ssl.update_ssl(
    hostname="example.com",
    ssl_certificate_is_active="Y",
    ssl_certificate_sni_key="-----BEGIN PRIVATE KEY-----\n...",
    ssl_certificate_sni_crt="-----BEGIN CERTIFICATE-----\n...",
    ssl_certificate_sni_bundle="-----BEGIN CERTIFICATE-----\n..."
)
```

**Parameters:**

| Parameter | Description |
|---|---|
| `hostname` | The hostname to configure |
| `ssl_certificate_is_active` | `Y`\|`N` (optional) |
| `ssl_certificate_sni_csr` | CSR (optional) |
| `ssl_certificate_sni_key` | Private Key |
| `ssl_certificate_sni_crt` | Certificate |
| `ssl_certificate_sni_bundle` | CA Bundle / Intermediate (optional) |
| `ssl_certificate_force_https` | `Y`\|`N` — HTTP 301 redirect (optional) |
| `ssl_certificate_hsts_max_age` | Seconds for HSTS, `-1` to disable (optional) |
