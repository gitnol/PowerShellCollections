from .base import BaseService
from typing import Dict, Any, List

class DdnsService(BaseService):
    """
    Handles DynDNS (DDNS) operations.
    """

    def get_ddnsusers(self, ddns_login: str = None) -> List[Dict[str, Any]]:
        """
        Auslesen der DDNS Benutzer
        """
        params = {}
        if ddns_login:
            params['ddns_login'] = ddns_login
            
        res = self.client.request('get_ddnsusers', params)
        if res and 'ReturnInfo' in res:
             return res['ReturnInfo']
        return []

    def add_ddnsuser(
        self, 
        dyndns_password: str, 
        dyndns_zone: str, 
        dyndns_label: str, 
        dyndns_target_ip: str, 
        dyndns_comment: str = None
    ) -> str:
        """
        Anlegen eines DDNS Benutzers
        """
        params = {
            'dyndns_password': dyndns_password,
            'dyndns_zone': dyndns_zone,
            'dyndns_label': dyndns_label,
            'dyndns_target_ip': dyndns_target_ip
        }
        if dyndns_comment:
            params['dyndns_comment'] = dyndns_comment
            
        res = self.client.request('add_ddnsuser', params)
        return res.get('ReturnInfo', 'TRUE')

    def delete_ddnsuser(self, dyndns_login: str) -> bool:
        """
        Löschen eines DDNS Benutzers
        """
        params = {'dyndns_login': dyndns_login}
        res = self.client.request('delete_ddnsuser', params)
        return res.get('ReturnString') == 'TRUE'

    def update_ddnsuser(
        self, 
        dyndns_login: str, 
        dyndns_password: str = None,
        dyndns_comment: str = None
    ) -> bool:
        """
        Bearbeiten eines DDNS Benutzers
        """
        params = {'dyndns_login': dyndns_login}
        if dyndns_password:
            params['dyndns_password'] = dyndns_password
        if dyndns_comment:
            params['dyndns_comment'] = dyndns_comment
            
        res = self.client.request('update_ddnsuser', params)
        return res.get('ReturnString') == 'TRUE'
