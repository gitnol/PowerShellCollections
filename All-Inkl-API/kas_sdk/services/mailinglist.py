from .base import BaseService
from typing import Dict, Any, List

class MailingListService(BaseService):
    """
    Handles MailingList operations.
    """

    def get_mailinglists(self, mailinglist_name: str = None, mailinglist_domain: str = None) -> List[Dict[str, Any]]:
        """
        Auslesen der Mailinglisten
        """
        params = {}
        if mailinglist_name:
            params['mailinglist_name'] = mailinglist_name
        if mailinglist_domain:
            params['mailinglist_domain'] = mailinglist_domain
            
        res = self.client.request('get_mailinglists', params)
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return []

    def add_mailinglist(self, mailinglist_name: str, mailinglist_domain: str, mailinglist_password: str) -> str:
        """
        Anlegen einer Mailingliste
        """
        params = {
            'mailinglist_name': mailinglist_name,
            'mailinglist_domain': mailinglist_domain,
            'mailinglist_password': mailinglist_password
        }
        res = self.client.request('add_mailinglist', params)
        return res.get('ReturnInfo', 'TRUE')

    def delete_mailinglist(self, mailinglist_name: str, mailinglist_domain: str) -> bool:
        """
        Löschen einer Mailingliste
        """
        params = {
            'mailinglist_name': mailinglist_name,
            'mailinglist_domain': mailinglist_domain
        }
        res = self.client.request('delete_mailinglist', params)
        return res.get('ReturnString') == 'TRUE'

    def update_mailinglist(
        self, 
        mailinglist_name: str, 
        mailinglist_domain: str, 
        mailinglist_new_password: str = None
    ) -> bool:
        """
        Bearbeiten der Mailingliste
        """
        params = {
            'mailinglist_name': mailinglist_name,
            'mailinglist_domain': mailinglist_domain
        }
        if mailinglist_new_password:
            params['mailinglist_new_password'] = mailinglist_new_password
            
        res = self.client.request('update_mailinglist', params)
        return res.get('ReturnString') == 'TRUE'
