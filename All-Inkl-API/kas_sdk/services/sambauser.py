from .base import BaseService
from typing import Dict, Any, List

class SambaUserService(BaseService):
    """
    Handles Samba User operations.
    """

    def get_sambausers(self, samba_login: str = None) -> List[Dict[str, Any]]:
        """
        Auslesen der Netzlaufwerke
        """
        params = {}
        if samba_login:
            params['samba_login'] = samba_login
        res = self.client.request('get_sambausers', params)
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return []

    def add_sambauser(
        self,
        samba_path: str,
        samba_new_password: str,
        samba_comment: str
    ) -> str:
        """
        Anlegen eines Netzlaufwerkes
        """
        params = {
            'samba_path': samba_path,
            'samba_new_password': samba_new_password,
            'samba_comment': samba_comment,
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
        samba_path: str = None,
        samba_comment: str = None
    ) -> bool:
        """
        Bearbeiten eines Netzlaufwerkes
        """
        params = {'samba_login': samba_login}
        if samba_new_password:
            params['samba_new_password'] = samba_new_password
        if samba_path:
            params['samba_path'] = samba_path
        if samba_comment:
            params['samba_comment'] = samba_comment

        res = self.client.request('update_sambauser', params)
        return res.get('ReturnString') == 'TRUE'
