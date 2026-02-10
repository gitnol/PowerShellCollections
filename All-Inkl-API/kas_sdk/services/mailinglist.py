from .base import BaseService
from typing import Dict, Any, List

class MailingListService(BaseService):
    """
    Handles MailingList operations.
    """

    def get_mailinglists(self, mailinglist_name: str = None) -> List[Dict[str, Any]]:
        """
        Auslesen der Mailinglisten
        """
        params = {}
        if mailinglist_name:
            params['mailinglist_name'] = mailinglist_name

        res = self.client.request('get_mailinglists', params)
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return []

    def add_mailinglist(
        self,
        mailinglist_name: str,
        mailinglist_domain: str,
        mailinglist_password: str
    ) -> str:
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

    def delete_mailinglist(self, mailinglist_name: str) -> bool:
        """
        Löschen einer Mailingliste
        """
        params = {'mailinglist_name': mailinglist_name}
        res = self.client.request('delete_mailinglist', params)
        return res.get('ReturnString') == 'TRUE'

    def update_mailinglist(
        self,
        mailinglist_name: str,
        config: str,
        subscriber: str = None,
        restrict_post: str = None,
        is_active: str = None
    ) -> bool:
        """
        Bearbeiten der Mailingliste
        """
        params = {
            'mailinglist_name': mailinglist_name,
            'config': config,
        }
        if subscriber is not None:
            params['subscriber'] = subscriber
        if restrict_post is not None:
            params['restrict_post'] = restrict_post
        if is_active is not None:
            params['is_active'] = is_active

        res = self.client.request('update_mailinglist', params)
        return res.get('ReturnString') == 'TRUE'
