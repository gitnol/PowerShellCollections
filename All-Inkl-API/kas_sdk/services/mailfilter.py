from .base import BaseService
from typing import Dict, Any, List

class MailFilterService(BaseService):
    """
    Handles MailFilter (standard filter) operations.
    Real API functions: add_mailstandardfilter, delete_mailstandardfilter, get_mailstandardfilter
    """

    def get_mailstandardfilter(self, mail_login: str = None) -> List[Dict[str, Any]]:
        """
        Auslesen der Mailfilter
        """
        params = {}
        if mail_login:
            params['mail_login'] = mail_login
        res = self.client.request('get_mailstandardfilter', params)
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return []

    def add_mailstandardfilter(self, mail_login: str, filter: str) -> bool:
        """
        Anlegen eines Mailfilters
        """
        params = {
            'mail_login': mail_login,
            'filter': filter
        }
        res = self.client.request('add_mailstandardfilter', params)
        return res.get('ReturnString') == 'TRUE'

    def delete_mailstandardfilter(self, mail_login: str) -> bool:
        """
        Löschen eines Mailfilters
        """
        params = {'mail_login': mail_login}
        res = self.client.request('delete_mailstandardfilter', params)
        return res.get('ReturnString') == 'TRUE'
