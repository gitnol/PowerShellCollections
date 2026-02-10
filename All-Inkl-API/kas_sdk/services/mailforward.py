from .base import BaseService
from typing import Dict, Any, List

class MailForwardService(BaseService):
    """
    Handles MailForward (Forwarder) operations.
    """

    def get_mailforwards(self, mail_forward: str = None) -> List[Dict[str, Any]]:
        """
        Auslesen der Weiterleitungen
        """
        params = {}
        if mail_forward:
            params['mail_forward'] = mail_forward

        res = self.client.request('get_mailforwards', params)
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return []

    def add_mailforward(
        self,
        local_part: str,
        domain_part: str,
        targets: List[str]
    ) -> str:
        """
        Anlegen einer Weiterleitung
        """
        params = {
            'local_part': local_part,
            'domain_part': domain_part,
        }
        for i, target in enumerate(targets):
            params[f'target_{i}'] = target
        res = self.client.request('add_mailforward', params)
        return res.get('ReturnInfo', 'TRUE')

    def delete_mailforward(self, mail_forward: str) -> bool:
        """
        Löschen einer Weiterleitung
        """
        params = {'mail_forward': mail_forward}
        res = self.client.request('delete_mailforward', params)
        return res.get('ReturnString') == 'TRUE'

    def update_mailforward(
        self,
        mail_forward: str,
        targets: List[str] = None
    ) -> bool:
        """
        Bearbeiten der Weiterleitung
        """
        params = {'mail_forward': mail_forward}
        if targets:
            for i, target in enumerate(targets):
                params[f'target_{i}'] = target
        res = self.client.request('update_mailforward', params)
        return res.get('ReturnString') == 'TRUE'
