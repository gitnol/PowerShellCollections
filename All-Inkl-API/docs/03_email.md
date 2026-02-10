# Email Infrastructure

## Table of Contents
*   [MailAccountService](#mailaccountservice)
*   [MailForwardService](#mailforwardservice)
*   [MailFilterService](#mailfilterservice)
*   [MailingListService](#mailinglistservice)
*   [DkimService](#dkimservice)

---

## MailAccountService
Found at `client.mailaccount`. Managing POP3/IMAP mailboxes.

### `get_mailaccounts(mail_login=None)`
List mail accounts.
```python
accounts = client.mailaccount.get_mailaccounts()
```

### `add_mailaccount(...)`
Create a mailbox.
```python
client.mailaccount.add_mailaccount(
    mail_password="SecretMailPassword1!",
    mail_local_part="info",
    mail_domain_part="example.com",
    mail_comment="Info Inbox"
)
```

### `update_mailaccount(...)`
Update password or comment.
```python
client.mailaccount.update_mailaccount(
    mail_login="m0123456",
    mail_password="NewPassword!"
)
```

### `delete_mailaccount(mail_login)`
Delete a mailbox.
```python
client.mailaccount.delete_mailaccount("m0123456")
```

---

## MailForwardService
Found at `client.mailforward`.

### `get_mailforwards(mail_forward: str = None)`
List forwarders.
```python
forwards = client.mailforward.get_mailforwards()
```

**Response Fields** — returns a list of dicts:

| Field                     | Description                                 |
|---------------------------|---------------------------------------------|
| `mail_forward_adress`     | Forward address (legacy spelling)           |
| `mail_forward_address`    | Forward address                             |
| `mail_forward_comment`    | Comment for the forwarder                   |
| `mail_forward_targets`    | Comma-separated target addresses            |
| `mail_forward_spamfilter` | Active spam filters (e.g. `kasgreyl,kaspdw`) |
| `in_progress`             | Operation pending (`TRUE`/`FALSE`)          |

### `add_mailforward(...)`
Create a forwarder (e.g. `support@example.com` -> `alice@example.com`).
```python
client.mailforward.add_mailforward(
    local_part="support",
    domain_part="example.com",
    targets=["alice@example.com", "bob@example.com"]
)
```

### `update_mailforward(...)`
```python
client.mailforward.update_mailforward(
    mail_forward="support@example.com",
    targets=["new_target@example.com"]
)
```

### `delete_mailforward(mail_forward: str)`
```python
client.mailforward.delete_mailforward("support@example.com")
```

---

## MailFilterService
Found at `client.mailfilter`. Manage server-side mail filter rules.

### `get_mailstandardfilter(mail_login: str = None)`
List mail filter rules.
```python
filters = client.mailfilter.get_mailstandardfilter()

# For a specific mailbox:
filters = client.mailfilter.get_mailstandardfilter(mail_login="m0123456")
```

### `add_mailstandardfilter(mail_login: str, filter: str)`
Add a mail filter rule for a mailbox.
```python
client.mailfilter.add_mailstandardfilter(
    mail_login="m0123456",
    filter="greyl;rbl_cbl:mark"
)
```

### `delete_mailstandardfilter(mail_login: str)`
```python
client.mailfilter.delete_mailstandardfilter("m0123456")
```

---

## MailingListService
Found at `client.mailinglist`.

### `get_mailinglists()`
List mailing lists.
```python
lists = client.mailinglist.get_mailinglists()
```

### `add_mailinglist(...)`
Create a list.
```python
client.mailinglist.add_mailinglist(
    mailinglist_name="newsletter",
    mailinglist_domain="example.com",
    mailinglist_password="ListAdminPass!"
)
```

### `update_mailinglist(...)`
```python
client.mailinglist.update_mailinglist(
    mailinglist_name="newsletter",
    config="# Full Mailman config text...",
    is_active="Y"
)
```

### `delete_mailinglist(mailinglist_name: str)`
```python
client.mailinglist.delete_mailinglist("newsletter")
```

---

## DkimService
Found at `client.dkim`. Manage DKIM signing for email domains.

### `get_dkim(host: str)`
Get DKIM status for a host.
```python
status = client.dkim.get_dkim("example.com")
```

**Response Fields** — returns a list of dicts:

| Field        | Description                              |
|--------------|------------------------------------------|
| `selector`   | DKIM selector name (e.g. `kas202512162044`) |
| `public_key` | RSA public key (Base64)                  |
| `valid_to`   | Expiry date (`YYYY-MM-DD`)               |

### `add_dkim(host: str, check_foreign_nameserver: str = "Y")`
Enable DKIM signing for a domain.
```python
client.dkim.add_dkim("example.com")
```

### `delete_dkim(host: str)`
Remove DKIM signing for a domain.
```python
client.dkim.delete_dkim("example.com")
```
