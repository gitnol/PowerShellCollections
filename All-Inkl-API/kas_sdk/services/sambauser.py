from .base import BaseService
from typing import Dict, Any, List

class SambaUserService(BaseService):
    """
    Handles Samba User operations.
    """

    def get_sambausers(self) -> List[Dict[str, Any]]:
        """
        Auslesen der Netzlaufwerke
        """
        res = self.client.request('get_sambausers', {})
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return []

    def add_sambauser(self, samba_path: str, samba_login: str, samba_password: str) -> str:
        """
        Anlegen eines Netzlaufwerkes
        """
        params = {
            'samba_path': samba_path,
            'samba_login': samba_login,
            'samba_password': samba_password
        }
        res = self.client.request('add_sambauser', params)
        return res.get('ReturnInfo', 'TRUE')

    def delete_sambauser(self, samba_login: str) -> bool:
        """
        Löschen eines Netzlaufwerkes
        """
        params = {'samba_login': samba_login}
        res = self.client.request('delete_sambauser', params)
        return res.get('ReturnString') == 'TRUE'

    def update_sambauser(
        self, 
        samba_login: str, 
        samba_new_password: str = None,
        samba_path: str = None
    ) -> bool:
        """
        Bearbeiten eines Netzlaufwerkes
        """
        params = {'samba_login': samba_login}
        if samba_new_password:
            params['samba_new_password'] = samba_new_password
        if samba_path:
            params['samba_path'] = samba_path
        
        res = self.client.request('update_sambauser', params)
        return res.get('ReturnString') == 'TRUE'
