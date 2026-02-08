from .base import BaseService
from typing import Dict, Any, List

class DkimService(BaseService):
    """
    Handles DKIM (DomainKeys Identified Mail) operations.
    """

    def get_dkim(self, host: str) -> List[Dict[str, Any]]:
        """
        Auslesen der DKIM Einstellungen
        """
        params = {'host': host}
        res = self.client.request('get_dkim', params)
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return []

    def add_dkim(self, host: str, check_foreign_nameserver: str = "Y") -> bool:
        """
        Anlegen eines DKIM Eintrages
        """
        params = {
            'host': host,
            'check_foreign_nameserver': check_foreign_nameserver
        }
        res = self.client.request('add_dkim', params)
        return res.get('ReturnString') == 'TRUE'

    def delete_dkim(self, host: str) -> bool:
        """
        Löschen eines DKIM Eintrages
        """
        params = {'host': host}
        res = self.client.request('delete_dkim', params)
        return res.get('ReturnString') == 'TRUE'
