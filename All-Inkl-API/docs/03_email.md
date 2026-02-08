# Email Infrastructure

## Table of Contents
*   [MailAccountService](#mailaccountservice)
*   [MailForwardService](#mailforwardservice)
*   [MailFilterService](#mailfilterservice)
*   [MailingListService](#mailinglistservice)

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
Found at `client.mailfilter`. Manage server-side rules (e.g. subject filtering).

### `get_mailfilters(filter_mail)`
List filters for a specific email address.
```python
filters = client.mailfilter.get_mailfilters(filter_mail="info@example.com")
```

### `add_mailfilter(...)`
Add a rule.
```python
client.mailfilter.add_mailfilter(
    filter_mail="info@example.com",
    filter_status="subject",
    filter_text="[SPAM]",
    filter_description="Block Spam Subject"
)
```

### `update_mailfilter(...)`
```python
client.mailfilter.update_mailfilter(
    filter_id="987",
    filter_text="[JUNK]"
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
Found at `client.dkim`.

### `get_dkim_settings(dkim_domain=None)`
Check DKIM status.
```python
# List all
dkim_status = client.dkim.get_dkim_settings()

# Check specific
status = client.dkim.get_dkim_settings("example.com")
```

### `update_dkim_settings(...)`
Enable or disable DKIM.
```python
client.dkim.update_dkim_settings(
    dkim_domain="example.com",
    dkim_active="Y"
)
```
