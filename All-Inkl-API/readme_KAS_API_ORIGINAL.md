# KAS API Documentation

## API Funktionen

### account

#### add_account

**Parameters**

```
array
```

folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- account_kas_password: KAS-Passwort des neuen Accounts
- account_ftp_password: FTP-Passwort des neuen Accounts
- account_comment: der Accountkommentar (optional, default = hostname_part1.hostname_part2)
- account_contact_mail: die Kontakt-Email (optional)
- hostname_art: Art des Accounts: domain|subdomain|,  = ohne Host
- domain:einen Subdomainaccount anlegen
- subdomain:einen Subdomainaccount anlegen
- leer lassen:einen Account ohne Host anlegen
- hostname_part1:  wenn hostname_art=domain: das Domainlabel (z.B.: "meine-domain") wenn hostname_art=subdomain: das Subdomainlabel (z.B.: "forum")  
- wenn hostname_art=domain: das Domainlabel (z.B.: "meine-domain")
- wenn hostname_art=subdomain: das Subdomainlabel (z.B.: "forum")
- hostname_part2:  wenn hostname_art=domain: das TLD Label (z.B.: "com" oder "de") wenn hostname_art=subdomain: die Domain zur Subdomain (z.B.: "meine-domain.de")  
- wenn hostname_art=domain: das TLD Label (z.B.: "com" oder "de")
- wenn hostname_art=subdomain: die Domain zur Subdomain (z.B.: "meine-domain.de")
- hostname_path: Pfad zum Hostnamen (optional, default /hostname_part1.hostname_part2/)
- max_account: maximale Anzahl an Unteraccounts, die der Account anlegen darf (optional, default 0)
- max_domain: maximale Anzahl an Domains (optional, default 0)
- max_subdomain: maximale Anzahl an Subdomains (optional, default 0)
- max_webspace: maximaler Speicherplatz in MB (optional, default 0)
- max_mail_account: maximale Anzahl an Postfächern (optional, default 0)
- max_mail_forward: maximale Anzahl an Weiterleitungen (optional, default 0)
- max_mailinglist: maximale Anzahl an Mailinglisten (optional, default 0)
- max_database: maximale Anzahl an MySQL Datenbanken (optional, default 0)
- max_ftpuser: maximale Anzahl an zusätzlichen FTP-Nutzern (optional, default 0)
- max_sambauser: maximale Anzahl an Netzlaufwerken (optional, default 0)
- max_cronjobs: maximale Anzahl an Cronjobs (optional, default 0)
- inst_htaccess: darf Verzeichnisschutz nutzen (optional, default Y)
- inst_fpse: darf Frontpage-Servererweiterung nutzen (optional, default N)
- kas_access_forbidden: Zugang zum KAS sperren (optional, default N)
- inst_software: darf Softwareinstallation nutzen (optional, default Y)
- logging: Log-Einstellung: voll|kurz|ohneip|keine (optional, default keine)
- logage: Logs werden nach x Tagen entfernt: 1-999 (optional, default 190)
- statistic: Statistiken (=/usage) erzeugen; in welcher Sprache? 0|de|ne (optional, default 0)
- dns_settings: darf DNS Einstellungen nutzen (optional, default N)
- show_password: Hinweis zum Anzeigen der Passwörter (optional, default N)
- domain:einen Subdomainaccount anlegen
- subdomain:einen Subdomainaccount anlegen
- leer lassen:einen Account ohne Host anlegen
- wenn hostname_art=domain: das Domainlabel (z.B.: "meine-domain")
- wenn hostname_art=subdomain: das Subdomainlabel (z.B.: "forum")
- wenn hostname_art=domain: das TLD Label (z.B.: "com" oder "de")
- wenn hostname_art=subdomain: die Domain zur Subdomain (z.B.: "meine-domain.de")

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\account_comment_syntax_incorrect
```
```
\account_contact_mail_syntax_incorrect
```
```
\account_ftp_password_syntax_incorrect
```
```
\account_kas_password_syntax_incorrect
```
```
\couldnt_get_kas_ressources
```
```
\dns_settings_not_allowed
```
```
\dns_settings_syntax_incorrect
```
```
\domain_syntax_incorrect
```
```
\domain_tld_not_allowed
```
```
\hostname_art_syntax_incorrect
```
```
\hostname_exist_as_domain
```
```
\hostname_exist_as_subdomain
```
```
\hostname_forbidden
```
```
\hostname_for_this_subdomain_doesnt_exist
```
```
\hostname_has_active_mail_addresses
```
```
\hostname_syntax_incorrect
```
```
\path_syntax_incorrect
```
```
\inst_fpse_syntax_incorrect
```
```
\inst_htaccess_syntax_incorrect
```
```
\inst_software_syntax_incorrect
```
```
\kas_access_forbidden_syntax_incorrect
```
```
\kas_login_syntax_incorrect
```
```
\logging_syntax_incorrect
```
```
\max_account_reached
```
```
\max_account_syntax_incorrect
```
```
\max_cron_reached
```
```
\max_cron_syntax_incorrect
```
```
\max_database_reached
```
```
\max_database_syntax_incorrect
```
```
\max_domain_reached
```
```
\max_domain_syntax_incorrect
```
```
\max_ftpuser_reached
```
```
\max_ftpuser_syntax_incorrect
```
```
\max_mail_account_reached
```
```
\max_mail_account_syntax_incorrect
```
```
\max_mail_forward_reached
```
```
\max_mail_forward_syntax_incorrect
```
```
\max_mailinglist_reached
```
```
\max_mailinglist_syntax_incorrect
```
```
\max_sambauser_reached
```
```
\max_sambauser_syntax_incorrect
```
```
\max_subdomain_reached
```
```
\max_subdomain_syntax_incorrect
```
```
\max_webspace_reached
```
```
\max_webspace_syntax_incorrect
```
```
\subdomain_syntax_incorrect
```
```
\wildcardsubdomain_not_in_contract
```

#### delete_account

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- account_login: das zu löschene Accountlogin

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\account_has_active_subaccounts
```
```
\account_kas_password_for_subaccount_incorrect
```
```
\account_login_not_found
```
```
\kas_login_not_found
```

#### get_accountresources

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp

**Exceptions**
```
\array_return
```

#### get_accountressources

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp

**Exceptions**
```
\array_return
```

#### get_accounts

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- account_login: das gewünschte Accountlogin (optional)

**Exceptions**
```
\array_return
```

#### get_accountsettings

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp

**Exceptions**
```
\array_return
```

#### get_server_information

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp

**Exceptions**
```
\array_return
```

#### update_account

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- account_login: der zu bearbeitende Account
- account_kas_password: das KAS-Passwort
- max_account: maximale Anzahl an Unteraccounts, die der Account anlegen darf (optional)
- max_domain: maximale Anzahl an Domains (optional)
- max_subdomain: maximale Anzahl an Subdomains (optional)
- max_webspace: maximaler Speicherplatz in MB (optional)
- max_mail_account: maximale Anzahl an Postfächern (optional)
- max_mail_forward: maximale Anzahl an Weiterleitungen (optional)
- max_mailinglist: maximale Anzahl an Mailinglisten (optional)
- max_database: maximale Anzahl an MySQL Datenbanken (optional)
- max_ftpuser: maximale Anzahl an zusätzlichen FTP-Nutzern (optional)
- max_sambauser: maximale Anzahl an Netzlaufwerken (optional)
- max_cronjobs: maximale Anzahl an Cronjobs (optional)
- inst_htaccess: darf Verzeichnisschutz nutzen (optional)
- inst_fpse: darf Frontpage-Servererweiterung nutzen (optional)
- kas_access_forbidden: Zugang sperren (optional: N|Y|forbidden)
- show_password: Hinweis zum Anzeigen der Passwörter (optional)
- inst_software: darf Softwareinstallation nutzen (optional)
- logging: Accesslog-Einstellung: voll|kurz|ohneip|keine (optional)
- logage: Logs werden nach x Tagen entfernt: 1-999 (optional, default 190)
- statistic: Statistiken (=/usage) erzeugen; in welcher Sprache? 0|de|ne (optional, default 0)
- dns_settings: darf DNS Einstellungen nutzen (optional)
- account_comment: der Accountkommentar (optional)
- account_contact_mail: die Kontakt-Email (optional)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\account_comment_syntax_incorrect
```
```
\account_contact_mail_syntax_incorrect
```
```
\account_kas_password_syntax_incorrect
```
```
\account_login_not_found
```
```
\couldnt_get_kas_ressources
```
```
\couldnt_get_subaccount_ressources
```
```
\dns_settings_not_allowed
```
```
\dns_settings_syntax_incorrect
```
```
\inst_fpse_not_allowed
```
```
\inst_fpse_syntax_incorrect
```
```
\inst_htaccess_not_allowed
```
```
\inst_htaccess_syntax_incorrect
```
```
\inst_software_not_allowed
```
```
\inst_software_syntax_incorrect
```
```
\kas_access_forbidden_syntax_incorrect
```
```
\logging_syntax_incorrect
```
```
\max_account_for_subaccount_gt_change_value
```
```
\max_account_reached
```
```
\max_account_syntax_incorrect
```
```
\max_cron_for_subaccount_gt_change_value
```
```
\max_cron_reached
```
```
\max_cron_syntax_incorrect
```
```
\max_database_for_subaccount_gt_change_value
```
```
\max_database_reached
```
```
\max_database_syntax_incorrect
```
```
\max_domain_for_subaccount_gt_change_value
```
```
\max_domain_reached
```
```
\max_domain_syntax_incorrect
```
```
\max_ftpuser_for_subaccount_gt_change_value
```
```
\max_ftpuser_reached
```
```
\max_ftpuser_syntax_incorrect
```
```
\max_mail_account_for_subaccount_gt_change_value
```
```
\max_mail_account_reached
```
```
\max_mail_account_syntax_incorrect
```
```
\max_mail_forward_for_subaccount_gt_change_value
```
```
\max_mail_forward_reached
```
```
\max_mail_forward_syntax_incorrect
```
```
\max_mailinglist_for_subaccount_gt_change_value
```
```
\max_mailinglist_reached
```
```
\max_mailinglist_syntax_incorrect
```
```
\max_sambauser_for_subaccount_gt_change_value
```
```
\max_sambauser_reached
```
```
\max_sambauser_syntax_incorrect
```
```
\max_subdomain_for_subaccount_gt_change_value
```
```
\max_subdomain_reached
```
```
\max_subdomain_syntax_incorrect
```
```
\max_webspace_for_subaccount_gt_change_value
```
```
\max_webspace_reached
```
```
\max_webspace_syntax_incorrect
```

#### update_accountsettings

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- account_password: das KAS-Passwort (optional)
- show_password: Hinweis zum Anzeigen der Passwörter (optional) (optional)
- logging: Accesslog-Einstellung: voll|kurz|ohneip|keine (optional)
- logage: Logs werden nach x Tagen entfernt: 1-999 (optional, default 190)
- statistic: Statistiken (=/usage) erzeugen; in welcher Sprache? 0|de|ne (optional, default 0)
- account_comment: der Accountkommentar (optional)
- account_contact_mail: die Kontakt-Email (optional)

**Exceptions**
```
TRUE
```
```
\in_progress
```
```
\nothing_to_do
```
```
\account_comment_syntax_incorrect
```
```
\account_contact_mail_syntax_incorrect
```
```
\account_kas_password_syntax_incorrect
```
```
\logging_syntax_incorrect
```
```
\show_password_syntax_incorrect
```

#### update_superusersettings

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- account_login: das zu bearbeitende Accountlogin
- ssh_access: aktiviert den SSH Zugang eines Accounts: Y|N (optional)
- ssh_keys: SSH Schlüssel für die Public-Key-Authentifizierung (optional)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\nothing_to_do
```
```
\account_doesnt_belong_to_you
```
```
\kas_login_is_no_main_login
```
```
\settings_not_in_contract
```
```
\ssh_access_syntax_incorrect
```
```
\ssh_keys_syntax_incorrect
```

### chown

#### update_chown

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- chown_path: der zu korrigierende Pfad 
- chown_user: der Zielnutzer: phpuser|kas_login (kas_login: z.B.: w0123456)
- recursive: Besitzrechte rekursiv setzen: Y|N

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\chownuser_syntax_incorrect
```
```
\directory_syntax_incorrect
```
```
\recursive_syntax_incorrect
```

### cronjob

#### add_cronjob

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- protocol: Cronjob Protokoll: http|https
- http_url: die Cronjob-URL
- cronjob_comment: der Cronjobkommentar
- minute: die ausführende Minute: */1-59|0-59|*
- hour: die ausführende Stunde: */1-23|1-23|*
- day_of_month: der ausführende Tag des Monats: 0-31|*
- month: der ausführende Monat: *
- day_of_week: der ausführende Wochentag: 0-7|* (Sonntag =0 oder =7)
- http_user: der HTTP-Auth Benutzer (optional)
- http_password: das HTTP-Auth Passwort (optional)
- mail_address: die Mailadresse, welche die Bestätigungsmail erhält: RFC2822 (optional)
- mail_condition: Bedingungswort: erscheint dieses in der Scriptausgab, so wird _keine_ E-Mail versendet (optional)
- mail_subject: verwende cronjob_comment als E-Mail-Subject: default|comment (optional, default)
- is_active: der Cronjob ist aktiv: Y|N (optional, default Y)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\couldnt_get_kas_ressources
```
```
\day_of_month_or_day_of_week_incorrect
```
```
\day_of_month_syntax_incorrect
```
```
\day_of_week_syntax_incorrect
```
```
\hour_syntax_incorrect
```
```
\http_password_syntax_incorrect
```
```
\protocol_syntax_incorrect
```
```
\http_url_syntax_incorrect
```
```
\http_user_syntax_incorrect
```
```
\is_active_syntax_incorrect
```
```
\mail_address_syntax_incorrect
```
```
\mail_condition_syntax_incorrect
```
```
\max_cronjobs_reached
```
```
\minute_syntax_incorrect
```
```
\month_syntax_incorrect
```
```
\time_not_allowed
```

#### delete_cronjob

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- cronjob_id: die zu löschende Cronjob ID, siehe get_cronjobs

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\cronjob_id_not_found
```
```
\cronjob_id_syntax_incorrect
```

#### get_cronjobs

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- cronjob_id: die ID des Cronjobs (optional)

**Exceptions**
```
\array_return
```

#### update_cronjob

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- cronjob_id: die zu bearbeitende Cronjob-ID
- protocol: Cronjob Protokoll: http|https (optional
- http_url: die Cronjob-URL (optional)
- cronjob_comment: der Cronjobkommentar (optional)
- minute: die ausführende Minute: */1-59|0-59|* (optional)
- hour: die ausführende Stunde: */1-23|1-23|* (optional)
- day_of_month: der ausführende Tag des Monats: 0-31|* (optional)
- month: der ausführende Monat: * (optional)
- day_of_week: der ausführende Wochentag: 0-7|* (Sonntag =0 oder =7, optional)
- http_user: der HTTP-Auth Benutzer (optional)
- http_password: das HTTP-Auth Passwort (optional)
- mail_address: die Mailadresse, welche die Bestätigungsmail erhält: RFC2822 (optional)
- mail_condition: Bedingungswort: erscheint dieses in der Scriptausgab, so wird _keine_ E-Mail versendet (optional)
- mail_subject: verwende cronjob_comment als E-Mail-Subject: default|comment (optional)
- is_active: der Cronjob ist aktiv: Y|N (optional)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\nothing_to_do
```
```
\cronjob_id_syntax_incorrect
```
```
\cronjob_not_found
```
```
\day_of_month_or_day_of_week_incorrect
```
```
\day_of_month_syntax_incorrect
```
```
\day_of_week_syntax_incorrect
```
```
\hour_syntax_incorrect
```
```
\http_password_syntax_incorrect
```
```
\protocol_syntax_incorrect
```
```
\http_url_syntax_incorrect
```
```
\http_user_syntax_incorrect
```
```
\is_active_syntax_incorrect
```
```
\mail_address_syntax_incorrect
```
```
\mail_condition_syntax_incorrect
```
```
\minute_syntax_incorrect
```
```
\month_syntax_incorrect
```
```
\time_not_allowed
```

### database

#### add_database

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- database_password: das Datenbankpasswort
- database_comment: der Datenbankkommentar
- database_allowed_hosts: erlaubte IP Adressen, die sich zur Datenbank verbinden dürfen (optional)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\account_is_dummyaccount
```
```
\cant_connect_to_mysql_on_this_server
```
```
\couldnt_get_kas_ressources
```
```
\database_allowed_hosts_syntax_incorrect
```
```
\database_comment_syntax_incorrect
```
```
\max_database_reached
```
```
\no_mysql_on_this_server
```
```
\password_syntax_incorrect
```

#### delete_database

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- database_login: das zu löschende Datenbanklogin

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\cant_connect_to_mysql_on_this_server
```
```
\database_login_not_found
```
```
\no_mysql_on_this_server
```

#### get_databases

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- database_login: die gewünsche Datenbank (optional)

**Exceptions**
```
\array_return
```

#### update_database

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- database_login: das betreffende Datenbanklogin
- database_new_password: das neue Datenbankpasswort (optional)
- database_comment: der Datenbankkommentar (optional)
- database_allowed_hosts: erlaubte IP Adressen, die sich zur Datenbank verbinden dürfen (optional)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\nothing_to_do
```
```
\cant_connect_to_mysql_on_this_server
```
```
\database_comment_syntax_incorrect
```
```
\database_login_not_found
```
```
\database_allowed_hosts_syntax_incorrect
```
```
\no_mysql_on_this_server
```
```
\password_syntax_incorrect
```

### ddns

#### add_ddnsuser

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- dyndns_comment: der Kommentar 
- dyndns_password: das Passwort 
- dyndns_zone: die Zone, für welche der DDNS Benutzer angelegt werden soll, z.B. domain.tld 
- dyndns_label: das Label, z.B. home 
- dyndns_target_ip: die IP, auf die der Benutzer anfangs zeigen soll

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\dyndns_comment_syntax_incorrect
```
```
\password_syntax_incorrect
```
```
\dyndns_target_ip_syntax_incorrect
```
```
\dyndns_label_not_allowed
```
```
\ddns_limit_reached
```
```
\dns_settings_not_allowed
```
```
\settings_not_in_contract
```
```
\record_name_syntax_incorrect
```

#### delete_ddnsuser

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- dyndns_login: das zu löschene Login

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\dyndns_login_not_found
```

#### get_ddnsusers

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- ddns_login: das gewünschte DDNS Login (optional)

**Exceptions**
```
\array_return
```

#### update_ddnsuser

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- dyndns_login: das betreffende Login
- dyndns_password: das neue Passwort (optional)
- dyndns_comment: der Kommentar (optional)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\nothing_to_do
```
```
\dyndns_comment_syntax_incorrect
```
```
\password_syntax_incorrect
```
```
\dyndns_target_ip_syntax_incorrect
```
```
\dns_settings_not_allowed
```

### directoryprotection

#### add_directoryprotection

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- directory_user: das Login
- directory_path: der Pfad
- directory_password: das Passwort
- directory_authname: der Kommentar

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\directory_password_syntax_incorrect
```
```
\directory_path_syntax_incorrect
```
```
\directory_user_count_neq_passcount
```
```
\directory_user_syntax_incorrect
```
```
\duplicate_directory_user
```
```
\max_directory_user_reached
```
```
\directory_authname_syntax_incorrect
```

#### delete_directoryprotection

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- directory_user: das Login
- directory_path: der Pfad

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\directory_password_syntax_incorrect
```

#### get_directoryprotection

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- directory_path: der Pfad (optional)

**Exceptions**
```
\array_return
```

#### update_directoryprotection

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- directory_user: das Login
- directory_path: der Pfad
- directory_password: das neue zu setzende Passwort
- directory_authname: der Kommentar

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\nothing_to_do
```
```
\directory_password_syntax_incorrect
```
```
\directory_path_syntax_incorrect
```
```
\directory_user_syntax_incorrect
```
```
\directory_authname_syntax_incorrect
```

### dkim

#### add_dkim

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- host: der betreffende Host
- check_foreign_nameserver: erzeugt Fehler, falls fremde NS hinterlegt sind. Y|N, default Y

**Exceptions**
```
TRUE
```
```
\spamfilter_not_in_contract
```
```
\host_not_found_in_kas
```
```
\foreign_nameserver_found
```
```
\couldnt_store_dkim
```

#### delete_dkim

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- host: der betreffende Host

**Exceptions**
```
TRUE
```
```
\host_not_found_in_kas
```

#### get_dkim

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- host: der betreffende Host

**Exceptions**
```
TRUE
```
```
\missing_host
```

### dns

#### add_dns_settings

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- zone_host: die betreffende Zone
- record_type: der TYPE des Resource Records (MX,A,AAAA usw)
- record_name: der NAME des Resource Records
- record_data: die DATA des Resource Records
- record_aux: die AUX des Resource Records

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\dns_settings_not_allowed
```
```
\record_already_exists
```
```
\record_already_exists_as_non_cname
```
```
\record_aux_syntax_incorrect
```
```
\record_has_ssl_certificate
```
```
\record_name_syntax_incorrect
```
```
\record_syntax_incorrect
```
```
\zone_not_found
```
```
\zone_syntax_incorrect
```

#### delete_dns_settings

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- record_id: die ID des Resource Records

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\dns_settings_not_allowed
```
```
\record_id_not_found
```
```
\record_id_syntax_incorrect
```
```
\record_is_not_changeable
```

#### get_dns_settings

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- zone_host: die betreffende Zone
- record_id: die ID des Resource Records (optional)

**Exceptions**
```
\array_return
```

#### reset_dns_settings

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- zone_host: die betreffende Zone
- nameserver: der betreffende Nameserver (optinal, default ns5.kasserver.com)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\nameserver_syntax_incorrect
```
```
\zone_not_found
```
```
\zone_syntax_incorrect
```

#### update_dns_settings

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- record_id: die ID des Resource Records
- record_name: der NAME des Resource Records (optional)
- record_data: die DATA des Resource Records (optional)
- record_aux: die AUX des Resource Records (optional)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\nothing_to_do
```
```
\dns_settings_not_allowed
```
```
\record_already_exists
```
```
\record_already_exists_as_cname
```
```
\record_already_exists_as_non_cname
```
```
\record_aux_syntax_incorrect
```
```
\record_has_ssl_certificate
```
```
\record_id_not_found
```
```
\record_id_syntax_incorrect
```
```
\record_is_not_changeable
```
```
\record_name_syntax_incorrect
```
```
\record_syntax_incorrect
```

### domain

#### add_domain

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- domain_name: Hostname ohne TLD
- domain_tld: die TLD
- domain_path: der Hostpfad im Account oder bei Redirect ein FQDN (optional, default /)
- redirect_status: Redirectstatus: 0|301|302|307, 0 = kein Redirect (optional, default 0)
- statistic_version: die Webalizerversion: 0|4|5|7 (optional, default 5)
- statistic_language: die Webalizersprache: de|en (optional, default de)
- php_version: die gewünschte PHP Version: 5.X|7.X (optional, default 7.1)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\host_is_dummyhost
```
```
\domain_tld_not_allowed
```
```
\redirect_status_syntax_incorrect
```
```
\couldnt_get_kas_ressources
```
```
\domain_path_syntax_incorrect
```
```
\domain_syntax_incorrect
```
```
\hostname_syntax_incorrect
```
```
\hostname_forbidden
```
```
\statistic_syntax_incorrect
```
```
\couldnt_get_kas_ressources
```
```
\max_domain_reached
```
```
\account_is_dummyaccount
```
```
\hostname_exists_as_domain
```
```
\php_version_syntax_incorrect
```
```
\php_version_not_available_on_server
```

#### delete_domain

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- domain_name: der zu löschende Hostname

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\domain_not_found_in_kas
```
```
\host_is_dummyhost
```
```
\subdomain_exists_in_subaccount
```

#### get_domains

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- domain_name: der gewünschte Hostname (optional)

**Exceptions**
```
\array_return
```

#### get_topleveldomains

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp

**Exceptions**
```
\array_return
```

#### move_domain

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- domain_name: der zu bearbeitende Hostname
- source_account: der Quellaccount
- target_account: der Zielaccount

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\kas_login_syntax_incorrect
```
```
\target_is_equal_to_source
```
```
\host_is_dummyhost
```
```
\account_doesnt_belong_to_you
```
```
\target_is_dummyaccount
```
```
\domain_not_found_in_kas
```
```
\subdomain_exists_in_subaccount
```
```
\domain_has_active_fpse
```
```
\max_domain_for_subaccount_gt_change_value
```
```
\max_subdomain_for_subaccount_gt_change_value
```
```
\max_mail_account_for_subaccount_gt_change_value
```
```
\max_mail_forward_for_subaccount_gt_change_value
```
```
\max_mailinglist_for_subaccount_gt_change_value
```
```
\ddns_settings_for_subaccount_disabled
```

#### update_domain

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- domain_name: der zu bearbeitende Hostname
- domain_path: der Hostpfad im Account oder bei Redirect ein FQDN (optional)
- redirect_status: Redirectstatus: 0|301|302|307, 0 = kein Redirect (optional)
- php_version: die gewünschte PHP Version: modul|5.X (optional)
- is_active: Domain ist aktiv: Y|N (optional)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\nothing_to_do
```
```
\redirect_status_syntax_incorrect
```
```
\redirect_status
```
```
\statistic_syntax_incorrect
```
```
\domain_not_found_in_kas
```
```
\domain_path_syntax_incorrect
```
```
\domain_has_active_fpse
```
```
\php_version_syntax_incorrect
```
```
\php_version_not_available_on_server
```
```
\is_active_syntax_incorrect
```

### ftpuser

#### add_ftpuser

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- ftp_password: das FTP Passwort
- ftp_comment: der Kommentar
- ftp_path: der Pfad zum Login (optional, default /)
- ftp_permission_read: der Nutzer darf lesen: Y|N (optional, default Y)
- ftp_permission_write: der Nutzer darf lesen: Y|N (optional, default Y)
- ftp_permission_list: der Nutzer darf lesen: Y|N (optional, default Y)
- ftp_virus_clamav: der Nutzer hat einen Virenschutz: Y|N (optional, default Y)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\couldnt_get_kas_ressources
```
```
\ftp_comment_syntax_incorrect
```
```
\ftp_permission_list_syntax_incorrect
```
```
\ftp_permission_read_syntax_incorrect
```
```
\ftp_permission_write_syntax_incorrect
```
```
\ftp_virus_clamav_syntax_incorrect
```
```
\max_ftpuser_reached
```
```
\missing_parameter
```
```
\password_syntax_incorrect
```
```
\path_syntax_incorrect
```

#### delete_ftpuser

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- ftp_login: das zu löschende Login

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\ftp_login_belongs_to_account
```
```
\ftp_login_not_found
```
```
\ftp_login_syntax_incorrect
```

#### get_ftpusers

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- ftp_login: das gewünschte FTP Login (optional)

**Exceptions**
```
\array_return
```

#### update_ftpuser

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- ftp_login: das zu bearbeitende Login
- ftp_path: der Pfad zum Login (optional)
- ftp_new_password: das neue FTP Passwort (optional)
- ftp_comment: der Kommentar (optional)
- ftp_permission_read: der Nutzer darf lesen: Y|N (optional)
- ftp_permission_write: der Nutzer darf lesen: Y|N (optional)
- ftp_permission_list: der Nutzer darf lesen: Y|N (optional)
- ftp_virus_clamav: der Nutzer hat einen Virenschutz: Y|N (optional)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\nothing_to_do
```
```
\ftp_comment_syntax_incorrect
```
```
\ftp_login_not_found
```
```
\ftp_login_syntax_incorrect
```
```
\ftp_path_syntax_incorrect
```
```
\ftp_permission_list_syntax_incorrect
```
```
\ftp_permission_read_syntax_incorrect
```
```
\ftp_permission_write_syntax_incorrect
```
```
\ftp_virus_clamav_syntax_incorrect
```
```
\password_syntax_incorrect
```

### mailaccount

#### add_mailaccount

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- mail_password: das Mailaccountpasswort
- webmail_autologin: automatisches Login vom KAS ins Webmail möglich: Y|N (optional, default Y)
- local_part: der local_part, RFC2822 
- domain_part: FQDN, RFC2822 
- responder: aktiver Responder: N|Y oder start|ende (start und ende als Timestamps mit "|" als Trenner, optional, default N)
- mail_responder_content_type: der Content-Type des Responder-Textes: html|text (optional, default text)
- mail_responder_displayname: der Anzeigename des Absenders bei dem Autoresponder, z.B. "mein Autoresponder Max Mustermann" (optional, default leer)
- responder_text: der Respondertext (optional, default leer)
- copy_adress: die Kopieempfängeradressen: RFC2822 (mehrere Adressen mit Komma getrennt sind möglich, optional, default leer)
- mail_sender_alias: erlaubte Aliasadressen, mit denen ein Versenden im FROM möglich ist (optional, default leer)
- mail_xlist_enabled: XLIST aktiv: Y|N (optional, default Y)
- mail_xlist_sent: XLIST Name "gesendete Objekte" (optional, default Sent)
- mail_xlist_drafts: XLIST Name "Entwürfe" (optional, default Drafts)
- mail_xlist_trash: XLIST Name "Papierkorb" (optional, default Trash)
- mail_xlist_spam: XLIST Name "Spam" (optional, default Spam)
- mail_xlist_archiv: XLIST Name "Archiv" (optional, default Archiv)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\copy_adress_like_mailaccount
```
```
\copy_adress_syntax_incorrect
```
```
\couldnt_get_kas_ressources
```
```
\email_already_exists
```
```
\email_domain_doesnt_exist
```
```
\email_syntax_incorrect
```
```
\mail_loop_detected
```
```
\max_emails_reached
```
```
\max_sender_alias_reached
```
```
\password_syntax_incorrect
```
```
\responder_contentype_syntax_incorrect
```
```
\responder_displayname_syntax_incorrect
```
```
\responder_not_allowed_for_catchall_adresses
```
```
\responder_startdate_gt_enddate
```
```
\responder_syntax_incorrect
```
```
\responder_text_is_empty
```
```
\sender_alias_domain_in_kas
```
```
\sender_alias_syntax_incorrect
```
```
\mail_xlist_enabled_syntax_incorrect
```
```
\mail_xlist_sent_syntax_incorrect
```
```
\mail_xlist_drafts_syntax_incorrect
```
```
\mail_xlist_trash_syntax_incorrect
```
```
\mail_xlist_spam_syntax_incorrect
```
```
\mail_xlist_archiv_syntax_incorrect
```
```
\mail_xlist_duplicate_folder
```
```
\webmail_autologin_syntax_incorrect
```

#### delete_mailaccount

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- mail_login: der zu löschende Mailaccount

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\mail_login_not_found
```
```
\mail_loop_detected
```

#### get_mailaccounts

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- mail_login: das gewünschte Maillogin (optional)

**Exceptions**
```
\array_return
```

#### update_mailaccount

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- mail_login: das zu bearbeitende Login
- mail_new_password: das neue Mailaccountpasswort (optional)
- webmail_autologin: automatisches Login vom KAS ins Webmail möglich: Y|N (optional, default Y)
- responder: aktiver Responder: N|Y oder start|ende (start und ende als Timestamps mit "|" als Trenner, optional)
- mail_responder_content_type: der Content-Type des Responder-Textes: html|text (optional)
- mail_responder_displayname: der Anzeigename des Absenders bei dem Autoresponder, z.B. "mein Autoresponder Max Mustermann" (optional)
- responder_text: der Respondertext (optional)
- copy_adress: die Kopieempfängeradressen: RFC2822 (mehrere Adressen mit Komma getrennt sind möglich, optional)
- is_active: ist das Postfach aktiv: Y|N|forbidden (N: kein Empfang aber Abruf ist noch möglich, optional)
- mail_sender_alias: erlaubte Aliasadressen, mit denen ein Versenden im FROM möglich ist (optional)
- mail_xlist_enabled: XLIST aktiv: Y|N (optional)
- mail_xlist_sent: XLIST Name "gesendete Objekte" (optional)
- mail_xlist_drafts: XLIST Name "Entwürfe" (optional)
- mail_xlist_trash: XLIST Name "Papierkorb" (optional)
- mail_xlist_spam: XLIST Name "Spam" (optional)
- mail_xlist_archiv: XLIST Name "Archiv" (optional)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\nothing_to_do
```
```
\copy_adress_like_mailaccount
```
```
\copy_adress_syntax_incorrect
```
```
\email_already_exists
```
```
\email_domain_doesnt_exist
```
```
\mail_loop_detected
```
```
\is_active_syntax_incorrect
```
```
\mail_login_not_found
```
```
\max_sender_alias_reached
```
```
\password_syntax_incorrect
```
```
\responder_contentype_syntax_incorrect
```
```
\responder_displayname_syntax_incorrect
```
```
\responder_not_allowed_for_catchall_adresses
```
```
\responder_startdate_gt_enddate
```
```
\responder_syntax_incorrect
```
```
\responder_text_is_empty
```
```
\sender_alias_domain_in_kas
```
```
\sender_alias_syntax_incorrect
```
```
\mail_xlist_enabled_syntax_incorrect
```
```
\mail_xlist_sent_syntax_incorrect
```
```
\mail_xlist_drafts_syntax_incorrect
```
```
\mail_xlist_trash_syntax_incorrect
```
```
\mail_xlist_spam_syntax_incorrect
```
```
\mail_xlist_archiv_syntax_incorrect
```
```
\mail_xlist_duplicate_folder
```
```
\webmail_autologin_syntax_incorrect
```
```
\webmail_autologin_change_requires_new_password
```

### mailfilter

#### add_mailfilter

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- mail_login: das Mailaccount Login
- filter: der Filter + Aktion: filter1:aktion1;filter2:aktion2...usw.  Filter: siehe Rückgabe get_mailstandardfilter Aktionen für Filter-Type Content: delete|mark|move=verzeichnis|forward=email@adresse.tld, für alle anderen Fitler-Typen lassen Sie die Aktion bitte leer Beispiel: greyl;rbl_cbl:mark -> Legt den Spamfilter Greylisting und Markiert Mails deren Absender in der RBL CBL gelistet sind  
- Filter: siehe Rückgabe get_mailstandardfilter
- Aktionen für Filter-Type Content: delete|mark|move=verzeichnis|forward=email@adresse.tld, für alle anderen Fitler-Typen lassen Sie die Aktion bitte leer
- Beispiel: greyl;rbl_cbl:mark -> Legt den Spamfilter Greylisting und Markiert Mails deren Absender in der RBL CBL gelistet sind

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\action_syntax_incorrect
```
```
\filter_doesnt_exist
```
```
\filter_not_allowed
```
```
\login_not_found
```
```
\mail_login_syntax_incorrect
```
```
\missing_parameter
```
```
\spamfilter_not_in_contract
```
```
\unknown_filtertype
```

#### delete_mailfilter

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- mail_login: das Login für welches die Filter entfernt werden sollen

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\login_not_found
```
```
\mail_login_syntax_incorrect
```

#### get_mailfilters

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp

**Exceptions**
```
\array_return
```

### mailforward

#### add_mailforward

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- local_part: der local_part, RFC2822 
- domain_part: FQDN, RFC2822 
- target_N: die Weiterleitungs-Ziele RFC2822 (N als fortlaufende Nummer, optional)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\couldnt_get_kas_ressources
```
```
\domain_part_doesnt_exist
```
```
\hostname_syntax_incorrect
```
```
\mail_forward_adress_syntax_incorrect
```
```
\mail_forward_exists_as_emailaccount
```
```
\mail_forward_exists_as_forward
```
```
\max_mail_forward_reached
```
```
\target_email_duplicate
```
```
\mail_loop_detected
```
```
\target_email_like_forward
```
```
\target_email_syntax_incorrect
```
```
\targets_limit_reached
```

#### delete_mailforward

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- mail_forward: die zu löschende Mail-Weiterleitung

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\mail_forward_domain_not_found_in_kas
```
```
\mail_forward_not_found_in_kas
```
```
\mail_loop_detected
```

#### get_mailforwards

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- mail_forward: die Mailweiterleitung (optional)

**Exceptions**
```
\array_return
```

#### update_mailforward

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- mail_forward: die zu bearbeitende Mail-Weiterleitung
- target_N: die Weiterleitungs-Ziele RFC2822 (N als fortlaufende Nummer, optional)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\nothing_to_do
```
```
\mail_forward_adress_syntax_incorrect
```
```
\mail_forward_not_found
```
```
\mail_loop_detected
```
```
\target_email_duplicate
```
```
\target_email_like_forward
```
```
\target_email_syntax_incorrect
```
```
\targets_limit_reached
```

### mailinglist

#### add_mailinglist

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- mailinglist_name: der Listenname
- mailinglist_domain: der Domainname zur Liste
- mailinglist_password: das Listenpasswort

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\couldnt_get_kas_ressources
```
```
\mailinglist_already_exists
```
```
\mailinglist_domain_doesnt_exist
```
```
\mailinglist_domain_syntax_incorrect
```
```
\mailinglist_syntax_incorrect
```
```
\max_mailinglists_reached
```
```
\missing_parameter
```
```
\password_syntax_incorrect
```

#### delete_mailinglist

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- mailinglist_name: die zu löschende Mailingliste

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\mailinglist_domain_not_found_in_kas
```
```
\mailinglist_not_found
```
```
\mailinglist_syntax_incorrect
```

#### get_mailinglists

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- mailinglist_name: die gewünsche Liste (optional)

**Exceptions**
```
\array_return
```

#### update_mailinglist

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- mailinglist_name: die zu bearbeitende Mailingliste
- subscriber: die Listenteilnehmer als RFC2822 (mehrere mit Zeilenumbruch getrennt, optional)
- restrict_post: die Resrict-Post-Adressen RFC2822 (mehrere mit Zeilenumbruch getrennt, optional)
- config: die komplette Konfigurationsdatei als Klartext
- is_active: ist die Mailingliste aktiv: Y|N (optional)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\cannot_connect_to_majordomo
```
```
\cannot_login_to_majordomo
```
```
\cannot_open_tmp_config
```
```
\cannot_open_tmp_restrict_post
```
```
\cannot_open_tmp_subscriber
```
```
\cannot_write_tmp_config
```
```
\cannot_write_tmp_restrict_post
```
```
\cannot_write_tmp_subscriber
```
```
\cannot_write_to_majordomo
```
```
\is_active_syntax_incorrect
```
```
\mailinglist_not_found
```
```
\mailinglist_syntax_incorrect
```
```
\parse_error_in_tmp_config
```
```
\restrict_post_email_syntax_incorrect
```
```
\subscriber_email_syntax_incorrect
```

### sambauser

#### add_sambauser

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- samba_path: der Pfad 
- samba_new_password: das Passwort 
- samba_comment: der Kommentar

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\couldnt_get_kas_ressources
```
```
\max_sambauser_reached
```
```
\password_syntax_incorrect
```
```
\path_syntax_incorrect
```
```
\samba_comment_syntax_incorrect
```

#### delete_sambauser

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- samba_login: das zu löschende Login

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\samba_login_not_found
```
```
\samba_login_syntax_incorrect
```

#### get_sambausers

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- samba_login: das gewünschte Login (optional)

**Exceptions**
```
\array_return
```

#### update_sambauser

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- samba_login: das Login
- samba_path: der Pfad (optional)
- samba_new_password: das neue Passwort (optional)
- samba_comment: der neue Kommentar (optional)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\nothing_to_do
```
```
\password_syntax_incorrect
```
```
\path_syntax_incorrect
```
```
\samba_comment_syntax_incorrect
```
```
\samba_login_not_found
```
```
\samba_login_syntax_incorrect
```

### session

#### create_session

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- session_lifetime: die Sessionlebenszeit in Sekunden: 1-30000
- session_update_lifetime: Verlängerung der Session bei deren Benutzung: Y|N
- session_2fa: der OTP Pin, falls eine 2-Faktor-Authentifizierung aktiv ist

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\session_lifetime_syntax_incorrect
```
```
\session_update_lifetime_syntax_incorrect
```

### softwareinstall

#### install_software

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- software_id: siehe Rückgabe get_softwareinstall
- software_database: die zu verwendende Datenbank
- software_database_password: das Datenbank-Passwort
- software_hostname: der Hostname zur Software
- software_install_example_data: falls möglich: sollen Beispieldaten installiert werden: Y|N (optional, default N)
- software_path: der Pfad zur Software
- software_admin_mail: die Mailadresse für die Bestätigungsmail, RFC2822 
- software_admin_user: der Admin-Benutzer
- software_admin_pass: das Passwort für den Adminzugang
- language: die Sprache in der die Bestätigungsmail verschickt wird: de|en (optional, default de)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\install_example_data_syntax_incorrect
```
```
\admin_mail_syntax_incorrect
```
```
\admin_user_syntax_incorrect
```
```
\admin_user_forbidden
```
```
\admin_password_forbidden
```
```
\domain_doesnt_exist
```
```
\host_using_redirect
```
```
\kas_inst_software_forbidden
```
```
\language_syntax_incorrect
```
```
\software_database_not_found
```
```
\software_id_not_found
```
```
\software_database_password_incorrect
```

#### get_softwareinstall

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- software_id: die betreffende Software ID (optional)

**Exceptions**
```
\array_return
```

### ssl

#### update_ssl

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- hostname: der zu bearbeitende Hostname
- ssl_certificate_is_active: SSL aktiv: Y|N (optional)
- ssl_certificate_sni_csr: der SSL CSR (optional)
- ssl_certificate_sni_key: der SSL KEY
- ssl_certificate_sni_crt: das SSL CRT
- ssl_certificate_sni_bundle: das Bundle / Intermediate (optional)
- ssl_certificate_force_https: HTTP Aufruf auf HTTPS umleiten (HTTP 301 Redirect): Y|N (optional)
- ssl_certificate_hsts_max_age: HTTP Strict Transport Security (HSTS) Wert in Sekunden, -1 um zu deaktivieren (optional)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\nothing_to_do
```
```
\ssl_certificate_is_active_syntax_incorrect
```
```
\ssl_certificate_sni_key_syntax_incorrect
```
```
\ssl_certificate_sni_crt_syntax_incorrect
```
```
\ssl_certificate_sni_crt_is_not_a_crt
```
```
\ssl_certificate_hostname_not_in_crt
```
```
\ssl_certificate_sni_csr_syntax_incorrect
```
```
\ssl_certificate_sni_bundle_syntax_incorrect
```
```
\ssl_certificate_sni_bundle_is_not_a_bundle
```
```
\ssl_certificate_sni_chainfile_syntax_incorrect
```
```
\ssl_certificate_sni_chainfile_is_not_a_chainfile
```
```
\ssl_certificate_sni_key_is_not_a_key
```
```
\ssl_certificate_hsts_max_age_syntax_incorrect
```
```
\ssl_certificate_force_https_syntax_incorrect
```

### statistic

#### get_usage

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- show_subaccounts: nur den Speicher der Unteraccounts anzeigen (optional, default N)
- show_details: Details zur Speicherbelegung. Beinhaltet Informationen zu Postfächern sowie Datenbanken (optional, default N)
ohne einen optionalen Parameter gibt die Funktion die Statistik des Accounts zurück

**Exceptions**
```
\array_return
```

#### get_directory_usage

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- directory: das Verzeichnis

**Exceptions**
```
\array_return
```

#### get_traffic

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- year: das Jahr (optional, default das aktuelle Jahr)
- month: der Monat (optional, default der aktuelle Monat)

**Exceptions**
```
\array_return
```

### subdomain

#### add_subdomain

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- subdomain_name: Label der Subdomain
- domain_name: die Domain zu der das Subdomainlabel hinzu gefügt werden soll
- subdomain_path: der Hostpfad im Account oder bei Redirect ein FQDN (optional, default /)
- redirect_status: Redirectstatus: 0|301|302|307, 0 = kein Redirect (optional, default 0)
- statistic_version: die Webalizerversion: 0|4|5|7 (optional, default 5)
- statistic_language: die Webalizersprache: de|en (optional, default de)
- php_version: die gewünschte PHP Version: 5.X|7.X (optional, default 7.1)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\account_is_dummyaccount
```
```
\domain_for_this_subdomain_doesnt_exist
```
```
\domain_syntax_incorrect
```
```
\max_subdomain_reached
```
```
\couldnt_get_kas_ressources
```
```
\redirect_status_syntax_incorrect
```
```
\statistic_syntax_incorrect
```
```
\subdomain_exist_as_subdomain
```
```
\subdomain_path_syntax_incorrect
```
```
\subdomain_syntax_incorrect
```
```
\wildcardsubdomain_not_in_contract
```
```
\php_version_syntax_incorrect
```
```
\php_version_not_available_on_server
```

#### delete_subdomain

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- subdomain_name: der zu löschende Hostname

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\host_is_dummyhost
```
```
\subdomain_doenst_exist
```

#### get_subdomains

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- subdomain_name: die gewünsche Subdomain (optional)

**Exceptions**
```
\array_return
```

#### move_subdomain

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- subdomain_name: der zu bearbeitende Hostname
- source_account: der Quellaccount
- target_account: der Zielaccount

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\nothing_to_do
```
```
\kas_login_syntax_incorrect
```
```
\target_is_equal_to_source
```
```
\host_is_dummyhost
```
```
\account_doesnt_belong_to_you
```
```
\subdomain_not_found_in_kas
```
```
\no_valid_parent_domain_there
```
```
\target_is_dummyaccount
```
```
\subdomain_has_active_fpse
```
```
\max_subdomain_for_subaccount_gt_change_value
```
```
\max_mail_account_for_subaccount_gt_change_value
```
```
\max_mail_forward_for_subaccount_gt_change_value
```
```
\max_mailinglist_for_subaccount_gt_change_value
```

#### update_subdomain

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- subdomain_name: der zu bearbeitende Hostname
- subdomain_path: der Hostpfad im Account oder bei Redirect ein FQDN (optional)
- redirect_status: Redirectstatus: 0|301|302|307, 0 = kein Redirect (optional)
- php_version: die gewünschte PHP Version: modul|5.X (optional)
- is_active: Domain ist aktiv: Y|N (optional)

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
```
\nothing_to_do
```
```
\redirect_status_syntax_incorrect
```
```
\statistic_syntax_incorrect
```
```
\subdomain_doenst_exist
```
```
\subdomain_has_active_fpse
```
```
\subdomain_path_syntax_incorrect
```
```
\php_version_syntax_incorrect
```
```
\php_version_not_available_on_server
```
```
\is_active_syntax_incorrect
```

### symlink

#### add_symlink

**Parameters**
```
array
```
folgende Parameter sind möglich:
- kas_login: das betreffende KAS Login
- kas_auth_data: die Authentifizierungsdaten
- kas_auth_type: der Authentifizierungstyp
- symlink_target: das Symlinkziel
- symlink_name: der Symlinkname

**Exceptions**
```
TRUE
```
```
\missing_parameter
```
```
\in_progress
```
