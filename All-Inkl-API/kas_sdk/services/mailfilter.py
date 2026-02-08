from .base import BaseService
from typing import Dict, Any, List

class MailFilterService(BaseService):
    """
    Handles MailFilter operations.
    """

    def get_mailfilters(self) -> List[Dict[str, Any]]:
        """
        Auslesen der Mailfilter
        """
        res = self.client.request('get_mailfilters', {})
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return []

    def add_mailfilter(self, mail_login: str, filter: str) -> bool:
        """
        Anlegen eines Mailfilters
        """
        params = {
            'mail_login': mail_login,
            'filter': filter
        }
        res = self.client.request('add_mailfilter', params)
        return res.get('ReturnString') == 'TRUE'

    def delete_mailfilter(self, mail_login: str) -> bool:
        """
        Löschen eines Mailfilters
        """
        params = {'mail_login': mail_login}
        res = self.client.request('delete_mailfilter', params)
        return res.get('ReturnString') == 'TRUE'
