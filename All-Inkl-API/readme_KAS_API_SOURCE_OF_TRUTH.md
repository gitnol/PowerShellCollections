## Package: account

### `add_account`

* **Req**: kas_login, kas_auth_data, kas_auth_type, account_kas_password, account_ftp_password, hostname_art, hostname_part1, hostname_part2
* **Opt**: account_comment, account_contact_mail, hostname_path [Def: /hostname_part1.hostname_part2/], max_account [Def: 0], max_domain [Def: 0], max_subdomain [Def: 0], max_webspace [Def: 0], max_mail_account [Def: 0], max_mail_forward [Def: 0], max_mailinglist [Def: 0], max_database [Def: 0], max_ftpuser [Def: 0], max_sambauser [Def: 0], max_cronjobs [Def: 0], inst_htaccess [Def: Y], inst_fpse [Def: N], kas_access_forbidden [Def: N], inst_software [Def: Y], logging [Def: keine], logage [Def: 190], statistic [Def: 0], dns_settings [Def: N], show_password [Def: N]
* **Exc**: \account_comment_syntax_incorrect, \account_contact_mail_syntax_incorrect, \account_ftp_password_syntax_incorrect, \account_kas_password_syntax_incorrect, \couldnt_get_kas_ressources, \dns_settings_not_allowed, \dns_settings_syntax_incorrect, \domain_syntax_incorrect, \domain_tld_not_allowed, \hostname_art_syntax_incorrect, \hostname_exist_as_domain, \hostname_exist_as_subdomain, \hostname_forbidden, \hostname_for_this_subdomain_doesnt_exist, \hostname_has_active_mail_addresses, \hostname_syntax_incorrect, \inst_fpse_syntax_incorrect, \inst_htaccess_syntax_incorrect, \inst_software_syntax_incorrect, \kas_access_forbidden_syntax_incorrect, \kas_login_syntax_incorrect, \logging_syntax_incorrect, \max_account_reached, \max_account_syntax_incorrect, \max_cron_reached, \max_cron_syntax_incorrect, \max_database_reached, \max_database_syntax_incorrect, \max_domain_reached, \max_domain_syntax_incorrect, \max_ftpuser_reached, \max_ftpuser_syntax_incorrect, \max_mail_account_reached, \max_mail_account_syntax_incorrect, \max_mail_forward_reached, \max_mail_forward_syntax_incorrect, \max_mailinglist_reached, \max_mailinglist_syntax_incorrect, \max_sambauser_reached, \max_sambauser_syntax_incorrect, \max_subdomain_reached, \max_subdomain_syntax_incorrect, \max_webspace_reached, \max_webspace_syntax_incorrect, \missing_parameter, \path_syntax_incorrect, \subdomain_syntax_incorrect, \wildcardsubdomain_not_in_contract

### `delete_account`

* **Req**: kas_login, kas_auth_data, kas_auth_type, account_login
* **Opt**: None
* **Exc**: \account_has_active_subaccounts, \account_kas_password_for_subaccount_incorrect, \account_login_not_found, \in_progress, \kas_login_not_found, \missing_parameter

### `get_accountresources`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: None
* **Exc**: \array_return

### `get_accountressources`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: None
* **Exc**: \array_return

### `get_accounts`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: account_login
* **Exc**: \array_return

### `get_accountsettings`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: None
* **Exc**: \array_return

### `get_server_information`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: None
* **Exc**: \array_return

### `update_account`

* **Req**: kas_login, kas_auth_data, kas_auth_type, account_login, account_kas_password
* **Opt**: max_account, max_domain, max_subdomain, max_webspace, max_mail_account, max_mail_forward, max_mailinglist, max_database, max_ftpuser, max_sambauser, max_cronjobs, inst_htaccess, inst_fpse, kas_access_forbidden, show_password, inst_software, logging, logage [Def: 190], statistic [Def: 0], dns_settings, account_comment, account_contact_mail
* **Exc**: \account_comment_syntax_incorrect, \account_contact_mail_syntax_incorrect, \account_kas_password_syntax_incorrect, \account_login_not_found, \couldnt_get_kas_ressources, \couldnt_get_subaccount_ressources, \dns_settings_not_allowed, \dns_settings_syntax_incorrect, \in_progress, \inst_fpse_not_allowed, \inst_fpse_syntax_incorrect, \inst_htaccess_not_allowed, \inst_htaccess_syntax_incorrect, \inst_software_not_allowed, \inst_software_syntax_incorrect, \kas_access_forbidden_syntax_incorrect, \logging_syntax_incorrect, \max_account_for_subaccount_gt_change_value, \max_account_reached, \max_account_syntax_incorrect, \max_cron_for_subaccount_gt_change_value, \max_cron_reached, \max_cron_syntax_incorrect, \max_database_for_subaccount_gt_change_value, \max_database_reached, \max_database_syntax_incorrect, \max_domain_for_subaccount_gt_change_value, \max_domain_reached, \max_domain_syntax_incorrect, \max_ftpuser_for_subaccount_gt_change_value, \max_ftpuser_reached, \max_ftpuser_syntax_incorrect, \max_mail_account_for_subaccount_gt_change_value, \max_mail_account_reached, \max_mail_account_syntax_incorrect, \max_mail_forward_for_subaccount_gt_change_value, \max_mail_forward_reached, \max_mail_forward_syntax_incorrect, \max_mailinglist_for_subaccount_gt_change_value, \max_mailinglist_reached, \max_mailinglist_syntax_incorrect, \max_sambauser_for_subaccount_gt_change_value, \max_sambauser_reached, \max_sambauser_syntax_incorrect, \max_subdomain_for_subaccount_gt_change_value, \max_subdomain_reached, \max_subdomain_syntax_incorrect, \max_webspace_for_subaccount_gt_change_value, \max_webspace_reached, \max_webspace_syntax_incorrect, \missing_parameter

### `update_accountsettings`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: account_password, show_password, logging, logage [Def: 190], statistic [Def: 0], account_comment, account_contact_mail
* **Exc**: \account_comment_syntax_incorrect, \account_contact_mail_syntax_incorrect, \account_kas_password_syntax_incorrect, \in_progress, \logging_syntax_incorrect, \nothing_to_do, \show_password_syntax_incorrect

### `update_superusersettings`

* **Req**: kas_login, kas_auth_data, kas_auth_type, account_login
* **Opt**: ssh_access, ssh_keys
* **Exc**: \account_doesnt_belong_to_you, \in_progress, \kas_login_is_no_main_login, \missing_parameter, \nothing_to_do, \settings_not_in_contract, \ssh_access_syntax_incorrect, \ssh_keys_syntax_incorrect

## Package: chown

### `update_chown`

* **Req**: kas_login, kas_auth_data, kas_auth_type, chown_path, chown_user, recursive
* **Opt**: None
* **Exc**: \chownuser_syntax_incorrect, \directory_syntax_incorrect, \in_progress, \missing_parameter, \recursive_syntax_incorrect

## Package: cronjob

### `add_cronjob`

* **Req**: kas_login, kas_auth_data, kas_auth_type, protocol, http_url, cronjob_comment, minute, hour, day_of_month, month, day_of_week
* **Opt**: http_user, http_password, mail_address, mail_condition, mail_subject [Def: comment], is_active [Def: Y]
* **Exc**: \couldnt_get_kas_ressources, \day_of_month_or_day_of_week_incorrect, \day_of_month_syntax_incorrect, \day_of_week_syntax_incorrect, \hour_syntax_incorrect, \http_password_syntax_incorrect, \http_url_syntax_incorrect, \http_user_syntax_incorrect, \is_active_syntax_incorrect, \mail_address_syntax_incorrect, \mail_condition_syntax_incorrect, \max_cronjobs_reached, \minute_syntax_incorrect, \missing_parameter, \month_syntax_incorrect, \protocol_syntax_incorrect, \time_not_allowed

### `delete_cronjob`

* **Req**: kas_login, kas_auth_data, kas_auth_type, cronjob_id
* **Opt**: None
* **Exc**: \cronjob_id_not_found, \cronjob_id_syntax_incorrect, \in_progress, \missing_parameter

### `get_cronjobs`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: cronjob_id
* **Exc**: \array_return

### `update_cronjob`

* **Req**: kas_login, kas_auth_data, kas_auth_type, cronjob_id
* **Opt**: protocol, http_url, cronjob_comment, minute, hour, day_of_month, month, day_of_week, http_user, http_password, mail_address, mail_condition, mail_subject, is_active
* **Exc**: \cronjob_id_syntax_incorrect, \cronjob_not_found, \day_of_month_or_day_of_week_incorrect, \day_of_month_syntax_incorrect, \day_of_week_syntax_incorrect, \hour_syntax_incorrect, \http_password_syntax_incorrect, \http_url_syntax_incorrect, \http_user_syntax_incorrect, \in_progress, \is_active_syntax_incorrect, \mail_address_syntax_incorrect, \mail_condition_syntax_incorrect, \minute_syntax_incorrect, \missing_parameter, \month_syntax_incorrect, \nothing_to_do, \protocol_syntax_incorrect, \time_not_allowed

## Package: database

### `add_database`

* **Req**: kas_login, kas_auth_data, kas_auth_type, database_password, database_comment
* **Opt**: database_allowed_hosts
* **Exc**: \account_is_dummyaccount, \cant_connect_to_mysql_on_this_server, \couldnt_get_kas_ressources, \database_allowed_hosts_syntax_incorrect, \database_comment_syntax_incorrect, \max_database_reached, \missing_parameter, \no_mysql_on_this_server, \password_syntax_incorrect

### `delete_database`

* **Req**: kas_login, kas_auth_data, kas_auth_type, database_login
* **Opt**: None
* **Exc**: \cant_connect_to_mysql_on_this_server, \database_login_not_found, \in_progress, \missing_parameter, \no_mysql_on_this_server

### `get_databases`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: database_login
* **Exc**: \array_return

### `update_database`

* **Req**: kas_login, kas_auth_data, kas_auth_type, database_login
* **Opt**: database_new_password, database_comment, database_allowed_hosts
* **Exc**: \cant_connect_to_mysql_on_this_server, \database_allowed_hosts_syntax_incorrect, \database_comment_syntax_incorrect, \database_login_not_found, \missing_parameter, \no_mysql_on_this_server, \nothing_to_do, \password_syntax_incorrect

## Package: ddns

### `add_ddnsuser`

* **Req**: kas_login, kas_auth_data, kas_auth_type, dyndns_comment, dyndns_password, dyndns_zone, dyndns_label, dyndns_target_ip
* **Opt**: None
* **Exc**: \ddns_limit_reached, \dns_settings_not_allowed, \dyndns_comment_syntax_incorrect, \dyndns_label_not_allowed, \dyndns_target_ip_syntax_incorrect, \missing_parameter, \password_syntax_incorrect, \record_name_syntax_incorrect, \settings_not_in_contract

### `delete_ddnsuser`

* **Req**: kas_login, kas_auth_data, kas_auth_type, dyndns_login
* **Opt**: None
* **Exc**: \dyndns_login_not_found, \missing_parameter

### `get_ddnsusers`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: ddns_login
* **Exc**: \array_return

### `update_ddnsuser`

* **Req**: kas_login, kas_auth_data, kas_auth_type, dyndns_login
* **Opt**: dyndns_password, dyndns_comment
* **Exc**: \dns_settings_not_allowed, \dyndns_comment_syntax_incorrect, \dyndns_target_ip_syntax_incorrect, \missing_parameter, \nothing_to_do, \password_syntax_incorrect

## Package: directoryprotection

### `add_directoryprotection`

* **Req**: kas_login, kas_auth_data, kas_auth_type, directory_user, directory_path, directory_password, directory_authname
* **Opt**: None
* **Exc**: \directory_authname_syntax_incorrect, \directory_password_syntax_incorrect, \directory_path_syntax_incorrect, \directory_user_count_neq_passcount, \directory_user_syntax_incorrect, \duplicate_directory_user, \max_directory_user_reached, \missing_parameter

### `delete_directoryprotection`

* **Req**: kas_login, kas_auth_data, kas_auth_type, directory_user, directory_path
* **Opt**: None
* **Exc**: \directory_password_syntax_incorrect, \in_progress, \missing_parameter

### `get_directoryprotection`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: directory_path
* **Exc**: \array_return

### `update_directoryprotection`

* **Req**: kas_login, kas_auth_data, kas_auth_type, directory_user, directory_path, directory_password, directory_authname
* **Opt**: None
* **Exc**: \directory_authname_syntax_incorrect, \directory_password_syntax_incorrect, \directory_path_syntax_incorrect, \directory_user_syntax_incorrect, \in_progress, \missing_parameter, \nothing_to_do

## Package: dkim

### `add_dkim`

* **Req**: kas_login, kas_auth_data, kas_auth_type, host, check_foreign_nameserver
* **Opt**: None
* **Exc**: \couldnt_store_dkim, \foreign_nameserver_found, \host_not_found_in_kas, \spamfilter_not_in_contract

### `delete_dkim`

* **Req**: kas_login, kas_auth_data, kas_auth_type, host
* **Opt**: None
* **Exc**: \host_not_found_in_kas

### `get_dkim`

* **Req**: kas_login, kas_auth_data, kas_auth_type, host
* **Opt**: None
* **Exc**: \missing_host

## Package: dns

### `add_dns_settings`

* **Req**: kas_login, kas_auth_data, kas_auth_type, zone_host, record_type, record_name, record_data, record_aux
* **Opt**: None
* **Exc**: \dns_settings_not_allowed, \missing_parameter, \record_already_exists, \record_already_exists_as_non_cname, \record_aux_syntax_incorrect, \record_has_ssl_certificate, \record_name_syntax_incorrect, \record_syntax_incorrect, \zone_not_found, \zone_syntax_incorrect

### `delete_dns_settings`

* **Req**: kas_login, kas_auth_data, kas_auth_type, record_id
* **Opt**: None
* **Exc**: \dns_settings_not_allowed, \in_progress, \missing_parameter, \record_id_not_found, \record_id_syntax_incorrect, \record_is_not_changeable

### `get_dns_settings`

* **Req**: kas_login, kas_auth_data, kas_auth_type, zone_host
* **Opt**: record_id
* **Exc**: \array_return

### `reset_dns_settings`

* **Req**: kas_login, kas_auth_data, kas_auth_type, zone_host
* **Opt**: nameserver [Def: ns5.kasserver.com]
* **Exc**: \in_progress, \missing_parameter, \nameserver_syntax_incorrect, \zone_not_found, \zone_syntax_incorrect

### `update_dns_settings`

* **Req**: kas_login, kas_auth_data, kas_auth_type, record_id
* **Opt**: record_name, record_data, record_aux
* **Exc**: \dns_settings_not_allowed, \in_progress, \missing_parameter, \nothing_to_do, \record_already_exists, \record_already_exists_as_cname, \record_already_exists_as_non_cname, \record_aux_syntax_incorrect, \record_has_ssl_certificate, \record_id_not_found, \record_id_syntax_incorrect, \record_is_not_changeable, \record_name_syntax_incorrect, \record_syntax_incorrect

## Package: domain

### `add_domain`

* **Req**: kas_login, kas_auth_data, kas_auth_type, domain_name, domain_tld
* **Opt**: domain_path [Def: /], redirect_status [Def: 0], statistic_version [Def: 5], statistic_language [Def: de], php_version [Def: 7.1]
* **Exc**: \account_is_dummyaccount, \couldnt_get_kas_ressources, \domain_path_syntax_incorrect, \domain_syntax_incorrect, \domain_tld_not_allowed, \host_is_dummyhost, \hostname_exists_as_domain, \hostname_forbidden, \hostname_syntax_incorrect, \max_domain_reached, \missing_parameter, \php_version_not_available_on_server, \php_version_syntax_incorrect, \redirect_status_syntax_incorrect, \statistic_syntax_incorrect

### `delete_domain`

* **Req**: kas_login, kas_auth_data, kas_auth_type, domain_name
* **Opt**: None
* **Exc**: \domain_not_found_in_kas, \host_is_dummyhost, \in_progress, \missing_parameter, \subdomain_exists_in_subaccount

### `get_domains`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: domain_name
* **Exc**: \array_return

### `get_topleveldomains`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: None
* **Exc**: \array_return

### `move_domain`

* **Req**: kas_login, kas_auth_data, kas_auth_type, domain_name, source_account, target_account
* **Opt**: None
* **Exc**: \account_doesnt_belong_to_you, \ddns_settings_for_subaccount_disabled, \domain_has_active_fpse, \domain_not_found_in_kas, \host_is_dummyhost, \in_progress, \kas_login_syntax_incorrect, \max_domain_for_subaccount_gt_change_value, \max_mail_account_for_subaccount_gt_change_value, \max_mail_forward_for_subaccount_gt_change_value, \max_mailinglist_for_subaccount_gt_change_value, \max_subdomain_for_subaccount_gt_change_value, \missing_parameter, \subdomain_exists_in_subaccount, \target_is_dummyaccount, \target_is_equal_to_source

### `update_domain`

* **Req**: kas_login, kas_auth_data, kas_auth_type, domain_name
* **Opt**: domain_path, redirect_status, php_version, is_active
* **Exc**: \domain_has_active_fpse, \domain_not_found_in_kas, \domain_path_syntax_incorrect, \in_progress, \is_active_syntax_incorrect, \missing_parameter, \nothing_to_do, \php_version_not_available_on_server, \php_version_syntax_incorrect, \redirect_status, \redirect_status_syntax_incorrect, \statistic_syntax_incorrect

## Package: ftpuser

### `add_ftpusers`

* **Req**: kas_login, kas_auth_data, kas_auth_type, ftp_password, ftp_comment
* **Opt**: ftp_path [Def: /], ftp_permission_read [Def: Y], ftp_permission_write [Def: Y], ftp_permission_list [Def: Y], ftp_virus_clamav [Def: Y]
* **Exc**: \couldnt_get_kas_ressources, \ftp_comment_syntax_incorrect, \ftp_permission_list_syntax_incorrect, \ftp_permission_read_syntax_incorrect, \ftp_permission_write_syntax_incorrect, \ftp_virus_clamav_syntax_incorrect, \max_ftpuser_reached, \missing_parameter, \password_syntax_incorrect, \path_syntax_incorrect

### `delete_ftpuser`

* **Req**: kas_login, kas_auth_data, kas_auth_type, ftp_login
* **Opt**: None
* **Exc**: \ftp_login_belongs_to_account, \ftp_login_not_found, \ftp_login_syntax_incorrect, \in_progress, \missing_parameter

### `get_ftpusers`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: ftp_login
* **Exc**: \array_return

### `update_ftpuser`

* **Req**: kas_login, kas_auth_data, kas_auth_type, ftp_login
* **Opt**: ftp_path, ftp_new_password, ftp_comment, ftp_permission_read, ftp_permission_write, ftp_permission_list, ftp_virus_clamav
* **Exc**: \ftp_comment_syntax_incorrect, \ftp_login_not_found, \ftp_login_syntax_incorrect, \ftp_path_syntax_incorrect, \ftp_permission_list_syntax_incorrect, \ftp_permission_read_syntax_incorrect, \ftp_permission_write_syntax_incorrect, \ftp_virus_clamav_syntax_incorrect, \in_progress, \missing_parameter, \nothing_to_do, \password_syntax_incorrect

## Package: mailaccount

### `add_mailaccount`

* **Req**: kas_login, kas_auth_data, kas_auth_type, mail_password, local_part, domain_part
* **Opt**: webmail_autologin [Def: Y], responder [Def: N], mail_responder_content_type [Def: text], mail_responder_displayname [Def: leer], responder_text [Def: leer], copy_adress [Def: leer], mail_sender_alias [Def: leer], mail_xlist_enabled [Def: Y], mail_xlist_sent [Def: Sent], mail_xlist_drafts [Def: Drafts], mail_xlist_trash [Def: Trash], mail_xlist_spam [Def: Spam], mail_xlist_archiv [Def: Archiv]
* **Exc**: \copy_adress_like_mailaccount, \copy_adress_syntax_incorrect, \couldnt_get_kas_ressources, \email_already_exists, \email_domain_doesnt_exist, \email_syntax_incorrect, \mail_loop_detected, \mail_xlist_archiv_syntax_incorrect, \mail_xlist_drafts_syntax_incorrect, \mail_xlist_duplicate_folder, \mail_xlist_enabled_syntax_incorrect, \mail_xlist_sent_syntax_incorrect, \mail_xlist_spam_syntax_incorrect, \mail_xlist_trash_syntax_incorrect, \max_emails_reached, \max_sender_alias_reached, \missing_parameter, \password_syntax_incorrect, \responder_contentype_syntax_incorrect, \responder_displayname_syntax_incorrect, \responder_not_allowed_for_catchall_adresses, \responder_startdate_gt_enddate, \responder_syntax_incorrect, \responder_text_is_empty, \sender_alias_domain_in_kas, \sender_alias_syntax_incorrect, \webmail_autologin_syntax_incorrect

### `delete_mailaccount`

* **Req**: kas_login, kas_auth_data, kas_auth_type, mail_login
* **Opt**: None
* **Exc**: \in_progress, \mail_login_not_found, \mail_loop_detected, \missing_parameter

### `get_mailaccounts`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: mail_login
* **Exc**: \array_return

### `update_mailaccount`

* **Req**: kas_login, kas_auth_data, kas_auth_type, mail_login
* **Opt**: mail_new_password, webmail_autologin [Def: Y], responder, mail_responder_content_type, mail_responder_displayname, responder_text, copy_adress, is_active, mail_sender_alias, mail_xlist_enabled, mail_xlist_sent, mail_xlist_drafts, mail_xlist_trash, mail_xlist_spam, mail_xlist_archiv
* **Exc**: \copy_adress_like_mailaccount, \copy_adress_syntax_incorrect, \email_already_exists, \email_domain_doesnt_exist, \in_progress, \is_active_syntax_incorrect, \mail_login_not_found, \mail_loop_detected, \mail_xlist_archiv_syntax_incorrect, \mail_xlist_drafts_syntax_incorrect, \mail_xlist_duplicate_folder, \mail_xlist_enabled_syntax_incorrect, \mail_xlist_sent_syntax_incorrect, \mail_xlist_spam_syntax_incorrect, \mail_xlist_trash_syntax_incorrect, \max_sender_alias_reached, \missing_parameter, \nothing_to_do, \password_syntax_incorrect, \responder_contentype_syntax_incorrect, \responder_displayname_syntax_incorrect, \responder_not_allowed_for_catchall_adresses, \responder_startdate_gt_enddate, \responder_syntax_incorrect, \responder_text_is_empty, \sender_alias_domain_in_kas, \sender_alias_syntax_incorrect, \webmail_autologin_change_requires_new_password, \webmail_autologin_syntax_incorrect

## Package: mailfilter

### `add_mailstandardfilter`

* **Req**: kas_login, kas_auth_data, kas_auth_type, mail_login, filter
* **Opt**: None
* **Exc**: \action_syntax_incorrect, \filter_doesnt_exist, \filter_not_allowed, \login_not_found, \mail_login_syntax_incorrect, \missing_parameter, \spamfilter_not_in_contract, \unknown_filtertype

### `delete_mailstandardfilter`

* **Req**: kas_login, kas_auth_data, kas_auth_type, mail_login
* **Opt**: None
* **Exc**: \in_progress, \login_not_found, \mail_login_syntax_incorrect, \missing_parameter

### `get_mailstandardfilter`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: None
* **Exc**: \array_return

## Package: mailforward

### `add_mailforward`

* **Req**: kas_login, kas_auth_data, kas_auth_type, local_part, domain_part
* **Opt**: target_N
* **Exc**: \couldnt_get_kas_ressources, \domain_part_doesnt_exist, \hostname_syntax_incorrect, \mail_forward_adress_syntax_incorrect, \mail_forward_exists_as_emailaccount, \mail_forward_exists_as_forward, \mail_loop_detected, \max_mail_forward_reached, \missing_parameter, \target_email_duplicate, \target_email_like_forward, \target_email_syntax_incorrect, \targets_limit_reached

### `delete_mailforward`

* **Req**: kas_login, kas_auth_data, kas_auth_type, mail_forward
* **Opt**: None
* **Exc**: \in_progress, \mail_forward_domain_not_found_in_kas, \mail_forward_not_found_in_kas, \mail_loop_detected, \missing_parameter

### `get_mailforwards`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: mail_forward
* **Exc**: \array_return

### `update_mailforward`

* **Req**: kas_login, kas_auth_data, kas_auth_type, mail_forward
* **Opt**: target_N
* **Exc**: \in_progress, \mail_forward_adress_syntax_incorrect, \mail_forward_not_found, \mail_loop_detected, \missing_parameter, \nothing_to_do, \target_email_duplicate, \target_email_like_forward, \target_email_syntax_incorrect, \targets_limit_reached

## Package: mailinglist

### `add_mailinglist`

* **Req**: kas_login, kas_auth_data, kas_auth_type, mailinglist_name, mailinglist_domain, mailinglist_password
* **Opt**: None
* **Exc**: \couldnt_get_kas_ressources, \mailinglist_already_exists, \mailinglist_domain_doesnt_exist, \mailinglist_domain_syntax_incorrect, \mailinglist_syntax_incorrect, \max_mailinglists_reached, \missing_parameter, \password_syntax_incorrect

### `delete_mailinglist`

* **Req**: kas_login, kas_auth_data, kas_auth_type, mailinglist_name
* **Opt**: None
* **Exc**: \in_progress, \mailinglist_domain_not_found_in_kas, \mailinglist_not_found, \mailinglist_syntax_incorrect, \missing_parameter

### `get_mailinglists`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: mailinglist_name
* **Exc**: \array_return

### `update_mailinglist`

* **Req**: kas_login, kas_auth_data, kas_auth_type, mailinglist_name, config
* **Opt**: subscriber, restrict_post, is_active
* **Exc**: \cannot_connect_to_majordomo, \cannot_login_to_majordomo, \cannot_open_tmp_config, \cannot_open_tmp_restrict_post, \cannot_open_tmp_subscriber, \cannot_write_tmp_config, \cannot_write_tmp_restrict_post, \cannot_write_tmp_subscriber, \cannot_write_to_majordomo, \in_progress, \is_active_syntax_incorrect, \mailinglist_not_found, \mailinglist_syntax_incorrect, \missing_parameter, \parse_error_in_tmp_config, \restrict_post_email_syntax_incorrect, \subscriber_email_syntax_incorrect

## Package: sambauser

### `add_sambauser`

* **Req**: kas_login, kas_auth_data, kas_auth_type, samba_path, samba_new_password, samba_comment
* **Opt**: None
* **Exc**: \couldnt_get_kas_ressources, \max_sambauser_reached, \missing_parameter, \password_syntax_incorrect, \path_syntax_incorrect, \samba_comment_syntax_incorrect

### `delete_sambauser`

* **Req**: kas_login, kas_auth_data, kas_auth_type, samba_login
* **Opt**: None
* **Exc**: \in_progress, \missing_parameter, \samba_login_not_found, \samba_login_syntax_incorrect

### `get_sambausers`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: samba_login
* **Exc**: \array_return

### `update_sambauser`

* **Req**: kas_login, kas_auth_data, kas_auth_type, samba_login
* **Opt**: samba_path, samba_new_password, samba_comment
* **Exc**: \in_progress, \missing_parameter, \nothing_to_do, \password_syntax_incorrect, \path_syntax_incorrect, \samba_comment_syntax_incorrect, \samba_login_not_found, \samba_login_syntax_incorrect

## Package: session

### `add_session`

* **Req**: kas_login, kas_auth_data, kas_auth_type, session_lifetime, session_update_lifetime, session_2fa
* **Opt**: None
* **Exc**: \missing_parameter, \session_lifetime_syntax_incorrect, \session_update_lifetime_syntax_incorrect

## Package: softwareinstall

### `add_softwareinstall`

* **Req**: kas_login, kas_auth_data, kas_auth_type, software_id, software_database, software_database_password, software_hostname, software_path, software_admin_mail, software_admin_user, software_admin_pass
* **Opt**: software_install_example_data [Def: N], language [Def: de]
* **Exc**: \admin_mail_syntax_incorrect, \admin_password_forbidden, \admin_user_forbidden, \admin_user_syntax_incorrect, \domain_doesnt_exist, \host_using_redirect, \in_progress, \install_example_data_syntax_incorrect, \kas_inst_software_forbidden, \language_syntax_incorrect, \missing_parameter, \software_database_not_found, \software_database_password_incorrect, \software_id_not_found

### `get_softwareinstall`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: software_id
* **Exc**: \array_return

## Package: ssl

### `update_ssl`

* **Req**: kas_login, kas_auth_data, kas_auth_type, hostname, ssl_certificate_sni_key, ssl_certificate_sni_crt
* **Opt**: ssl_certificate_is_active, ssl_certificate_sni_csr, ssl_certificate_sni_bundle, ssl_certificate_force_https, ssl_certificate_hsts_max_age
* **Exc**: \in_progress, \missing_parameter, \nothing_to_do, \ssl_certificate_force_https_syntax_incorrect, \ssl_certificate_hostname_not_in_crt, \ssl_certificate_hsts_max_age_syntax_incorrect, \ssl_certificate_is_active_syntax_incorrect, \ssl_certificate_sni_bundle_is_not_a_bundle, \ssl_certificate_sni_bundle_syntax_incorrect, \ssl_certificate_sni_chainfile_is_not_a_chainfile, \ssl_certificate_sni_chainfile_syntax_incorrect, \ssl_certificate_sni_crt_is_not_a_crt, \ssl_certificate_sni_crt_syntax_incorrect, \ssl_certificate_sni_csr_syntax_incorrect, \ssl_certificate_sni_key_is_not_a_key, \ssl_certificate_sni_key_syntax_incorrect

## Package: statistic

### `get_space`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: show_subaccounts [Def: N], show_details [Def: N]
* **Exc**: \array_return

### `get_space_usage`

* **Req**: kas_login, kas_auth_data, kas_auth_type, directory
* **Opt**: None
* **Exc**: \array_return

### `get_traffic`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: year, month
* **Exc**: \array_return

## Package: subdomain

### `add_subdomain`

* **Req**: kas_login, kas_auth_data, kas_auth_type, subdomain_name, domain_name
* **Opt**: subdomain_path [Def: /], redirect_status [Def: 0], statistic_version [Def: 5], statistic_language [Def: de], php_version [Def: 7.1]
* **Exc**: \account_is_dummyaccount, \couldnt_get_kas_ressources, \domain_for_this_subdomain_doesnt_exist, \domain_syntax_incorrect, \max_subdomain_reached, \missing_parameter, \php_version_not_available_on_server, \php_version_syntax_incorrect, \redirect_status_syntax_incorrect, \statistic_syntax_incorrect, \subdomain_exist_as_subdomain, \subdomain_path_syntax_incorrect, \subdomain_syntax_incorrect, \wildcardsubdomain_not_in_contract

### `delete_subdomain`

* **Req**: kas_login, kas_auth_data, kas_auth_type, subdomain_name
* **Opt**: None
* **Exc**: \host_is_dummyhost, \in_progress, \missing_parameter, \subdomain_doenst_exist

### `get_subdomains`

* **Req**: kas_login, kas_auth_data, kas_auth_type
* **Opt**: subdomain_name
* **Exc**: \array_return

### `move_subdomain`

* **Req**: kas_login, kas_auth_data, kas_auth_type, subdomain_name, source_account, target_account
* **Opt**: None
* **Exc**: \account_doesnt_belong_to_you, \host_is_dummyhost, \in_progress, \kas_login_syntax_incorrect, \max_mail_account_for_subaccount_gt_change_value, \max_mail_forward_for_subaccount_gt_change_value, \max_mailinglist_for_subaccount_gt_change_value, \max_subdomain_for_subaccount_gt_change_value, \missing_parameter, \no_valid_parent_domain_there, \nothing_to_do, \subdomain_has_active_fpse, \subdomain_not_found_in_kas, \target_is_dummyaccount, \target_is_equal_to_source

### `update_subdomain`

* **Req**: kas_login, kas_auth_data, kas_auth_type, subdomain_name
* **Opt**: subdomain_path, redirect_status, php_version, is_active
* **Exc**: \in_progress, \is_active_syntax_incorrect, \missing_parameter, \nothing_to_do, \php_version_not_available_on_server, \php_version_syntax_incorrect, \redirect_status_syntax_incorrect, \statistic_syntax_incorrect, \subdomain_doenst_exist, \subdomain_has_active_fpse, \subdomain_path_syntax_incorrect

## Package: symlink

### `add_symlink`

* **Req**: kas_login, kas_auth_data, kas_auth_type, symlink_target, symlink_name
* **Opt**: None
* **Exc**: \in_progress, \missing_parameter