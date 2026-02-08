from .base import BaseService
from typing import Dict, Any, List

class AccountService(BaseService):
    """
    Handles Account operations.
    """

    def get_accounts(self, account_login: str = None) -> List[Dict[str, Any]]:
        """
        Auslesen der Accounts
        """
        params = {}
        if account_login:
            params['account_login'] = account_login
        res = self.client.request('get_accounts', params)
        if res and 'ReturnInfo' in res:
             return res['ReturnInfo']
        return []

    def add_account(
        self, 
        account_kas_password: str, 
        account_ftp_password: str, 
        hostname_art: str, 
        hostname_part1: str = None, 
        hostname_part2: str = None,
        account_comment: str = None,
        account_contact_mail: str = None,
        hostname_path: str = None,
        max_account: int = None,
        max_domain: int = None,
        max_subdomain: int = None,
        max_webspace: int = None,
        max_mail_account: int = None,
        max_mail_forward: int = None,
        max_mailinglist: int = None,
        max_database: int = None,
        max_ftpuser: int = None,
        max_sambauser: int = None,
        max_cronjobs: int = None,
        inst_htaccess: str = None,
        inst_fpse: str = None,
        kas_access_forbidden: str = None,
        inst_software: str = None,
        logging: str = None,
        logage: int = None,
        statistic: str = None,
        dns_settings: str = None,
        show_password: str = None,
    ) -> bool:
        """
        Anlegen eines Accounts
        """
        params = {
            'account_kas_password': account_kas_password,
            'account_ftp_password': account_ftp_password,
            'hostname_art': hostname_art
        }
        
        optional_params = {
            'hostname_part1': hostname_part1,
            'hostname_part2': hostname_part2,
            'account_comment': account_comment,
            'account_contact_mail': account_contact_mail,
            'hostname_path': hostname_path,
            'max_account': max_account,
            'max_domain': max_domain,
            'max_subdomain': max_subdomain,
            'max_webspace': max_webspace,
            'max_mail_account': max_mail_account,
            'max_mail_forward': max_mail_forward,
            'max_mailinglist': max_mailinglist,
            'max_database': max_database,
            'max_ftpuser': max_ftpuser,
            'max_sambauser': max_sambauser,
            'max_cronjobs': max_cronjobs,
            'inst_htaccess': inst_htaccess,
            'inst_fpse': inst_fpse,
            'kas_access_forbidden': kas_access_forbidden,
            'inst_software': inst_software,
            'logging': logging,
            'logage': logage,
            'statistic': statistic,
            'dns_settings': dns_settings,
            'show_password': show_password,
        }
        
        for k, v in optional_params.items():
            if v is not None:
                params[k] = v
        
        res = self.client.request('add_account', params)
        return res.get('ReturnString') == 'TRUE'

    def delete_account(self, account_login: str) -> bool:
        """
        Löschen eines Accounts
        """
        params = {'account_login': account_login}
        res = self.client.request('delete_account', params)
        return res.get('ReturnString') == 'TRUE'

    def update_account(
        self, 
        account_login: str, 
        account_kas_password: str = None,
        max_account: int = None,
        max_domain: int = None,
        max_subdomain: int = None,
        max_webspace: int = None,
        max_mail_account: int = None,
        max_mail_forward: int = None,
        max_mailinglist: int = None,
        max_database: int = None,
        max_ftpuser: int = None,
        max_sambauser: int = None,
        max_cronjobs: int = None,
        inst_htaccess: str = None,
        inst_fpse: str = None,
        kas_access_forbidden: str = None,
        show_password: str = None,
        inst_software: str = None,
        logging: str = None,
        logage: int = None,
        statistic: str = None,
        dns_settings: str = None,
        account_comment: str = None,
        account_contact_mail: str = None
    ) -> bool:
        """
        Bearbeiten eines Accounts
        """
        params = {'account_login': account_login}
        
        optional_params = {
            'account_kas_password': account_kas_password,
            'max_account': max_account,
            'max_domain': max_domain,
            'max_subdomain': max_subdomain,
            'max_webspace': max_webspace,
            'max_mail_account': max_mail_account,
            'max_mail_forward': max_mail_forward,
            'max_mailinglist': max_mailinglist,
            'max_database': max_database,
            'max_ftpuser': max_ftpuser,
            'max_sambauser': max_sambauser,
            'max_cronjobs': max_cronjobs,
            'inst_htaccess': inst_htaccess,
            'inst_fpse': inst_fpse,
            'kas_access_forbidden': kas_access_forbidden,
            'show_password': show_password,
            'inst_software': inst_software,
            'logging': logging,
            'logage': logage,
            'statistic': statistic,
            'dns_settings': dns_settings,
            'account_comment': account_comment,
            'account_contact_mail': account_contact_mail
        }
        
        for k, v in optional_params.items():
            if v is not None:
                params[k] = v
        
        res = self.client.request('update_account', params)
        return res.get('ReturnString') == 'TRUE'

    def get_accountresources(self) -> Dict[str, Any]:
        """
        Auslesen der Accountressourcen
        """
        # NO params according to docs
        res = self.client.request('get_accountresources', {})
        if res and 'ReturnInfo' in res:
             return res['ReturnInfo']
        return {}

    def get_accountsettings(self) -> Dict[str, Any]:
        """
        Auslesen der Accounteinstellungen
        """
        # NO params according to docs
        res = self.client.request('get_accountsettings', {})
        if res and 'ReturnInfo' in res:
             return res['ReturnInfo']
        return {}

    def get_server_information(self) -> Dict[str, Any]:
        """
        Auslesen der zusätzlichen Serverinformationen zum Account
        """
        res = self.client.request('get_server_information', {})
        if res and 'ReturnInfo' in res:
             return res['ReturnInfo']
        return {}

    def update_accountsettings(
        self, 
        account_password: str = None,
        show_password: str = None,
        logging: str = None,
        logage: int = None,
        statistic: str = None,
        account_comment: str = None,
        account_contact_mail: str = None
    ) -> bool:
        """
        Bearbeiten der eigenen Accounteinstellungen
        """
        params = {}
        
        optional_params = {
            'account_password': account_password,
            'show_password': show_password,
            'logging': logging,
            'logage': logage,
            'statistic': statistic,
            'account_comment': account_comment,
            'account_contact_mail': account_contact_mail
        }
        
        for k, v in optional_params.items():
            if v is not None:
                params[k] = v

        if not params:
            return True # Nothing to do

        res = self.client.request('update_accountsettings', params)
        return res.get('ReturnString') == 'TRUE'

    def update_superusersettings(
        self, 
        account_login: str, 
        ssh_access: str = None,
        ssh_keys: str = None
    ) -> bool:
        """
        Bearbeiten der Superuser-Accounteinstellungen
        """
        params = {'account_login': account_login}
        if ssh_access:
            params['ssh_access'] = ssh_access
        if ssh_keys:
            params['ssh_keys'] = ssh_keys
        
        res = self.client.request('update_superusersettings', params)
        return res.get('ReturnString') == 'TRUE'
