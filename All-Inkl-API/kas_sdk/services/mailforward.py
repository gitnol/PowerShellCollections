from .base import BaseService
from typing import Dict, Any, List

class MailForwardService(BaseService):
    """
    Handles MailForward (Forwarder) operations.
    """

    def get_mailforwards(self, mail_forward_id: int = None) -> List[Dict[str, Any]]:
        """
        Auslesen der Weiterleitungen
        """
        params = {}
        if mail_forward_id:
            params['mail_forward_id'] = mail_forward_id
            
        res = self.client.request('get_mailforwards', params)
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return []

    def add_mailforward(self, mail_forward_part1: str, mail_forward_part2: str, mail_forward_target: str) -> str:
        """
        Anlegen einer Weiterleitung
        """
        params = {
            'mail_forward_part1': mail_forward_part1,
            'mail_forward_part2': mail_forward_part2,
            'mail_forward_target': mail_forward_target
        }
        res = self.client.request('add_mailforward', params)
        return res.get('ReturnInfo', 'TRUE')

    def delete_mailforward(self, mail_forward_id: str) -> bool:
        """
        Löschen einer Weiterleitung
        """
        params = {'mail_forward_id': mail_forward_id}
        res = self.client.request('delete_mailforward', params)
        return res.get('ReturnString') == 'TRUE'

    def update_mailforward(self, mail_forward_id: str, mail_forward_target: str) -> bool:
        """
        Bearbeiten der Weiterleitung
        """
        params = {
            'mail_forward_id': mail_forward_id,
            'mail_forward_target': mail_forward_target
        }
        res = self.client.request('update_mailforward', params)
        return res.get('ReturnString') == 'TRUE'
