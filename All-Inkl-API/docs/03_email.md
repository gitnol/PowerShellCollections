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

### `get_mailforwards()`
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
    mail_forward_part1="support",
    mail_forward_part2="example.com",
    mail_forward_target="alice@example.com, bob@example.com"
)
```

### `update_mailforward(...)`
```python
client.mailforward.update_mailforward(
    mail_forward_id="12345",
    mail_forward_target="new_target@example.com"
)
```

### `delete_mailforward(mail_forward_id)`
```python
client.mailforward.delete_mailforward("123456")
```

---

## MailFilterService
Found at `client.mailfilter`. Manage server-side mail filter rules.

> [!WARNING]
> The `get_mailfilters` action does **not** exist in the KAS API (returns `unkown_action`).
> Only `add_mailfilter` and `delete_mailfilter` are supported.

### `add_mailfilter(...)`
Add a mail filter rule.
```python
client.mailfilter.add_mailfilter(
    filter_mail="info@example.com",
    filter_status="subject",
    filter_text="[SPAM]",
    filter_description="Block Spam Subject"
)
```

### `delete_mailfilter(filter_id)`
```python
client.mailfilter.delete_mailfilter("98765")
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
    mailinglist_domain="example.com",
    mailinglist_password="NewListPassword!"
)
```

### `delete_mailinglist(mailinglist_name, mailinglist_domain)`
```python
client.mailinglist.delete_mailinglist(
    mailinglist_name="newsletter",
    mailinglist_domain="example.com"
)
```

---

## DkimService
Found at `client.dkim`. Manage DKIM signing for email domains.

### `get_dkim(dkim_domain=None)`
Get DKIM status for domains.
```python
# List all
dkim_status = client.dkim.get_dkim()

# Check specific
status = client.dkim.get_dkim("example.com")
```

**Response Fields** — returns a list of dicts:

| Field        | Description                              |
|--------------|------------------------------------------|
| `selector`   | DKIM selector name (e.g. `kas202512162044`) |
| `public_key` | RSA public key (Base64)                  |
| `valid_to`   | Expiry date (`YYYY-MM-DD`)               |

### `add_dkim(dkim_domain: str)`
Enable DKIM signing for a domain.
```python
client.dkim.add_dkim("example.com")
```

### `delete_dkim(dkim_domain: str)`
Remove DKIM signing for a domain.
```python
client.dkim.delete_dkim("example.com")
```
