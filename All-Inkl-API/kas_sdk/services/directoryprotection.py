from .base import BaseService
from typing import Dict, Any, List

class DirectoryProtectionService(BaseService):
    """
    Handles Directory Protection (.htaccess auth) operations.
    """

    def get_directoryprotection(self, directory_path: str = None) -> List[Dict[str, Any]]:
        """
        Auslesen des Verzeichnisschutzes
        """
        params = {}
        if directory_path:
            params['directory_path'] = directory_path
            
        res = self.client.request('get_directoryprotection', params)
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return []

    def add_directoryprotection(
        self, 
        directory_path: str, 
        directory_user: str, 
        directory_password: str, 
        directory_authname: str
    ) -> bool:
        """
        Anlegen eines Verzeichnisschutzes
        """
        params = {
            'directory_path': directory_path,
            'directory_user': directory_user,
            'directory_password': directory_password,
            'directory_authname': directory_authname
        }
        res = self.client.request('add_directoryprotection', params)
        return res.get('ReturnString') == 'TRUE'

    def delete_directoryprotection(self, directory_user: str, directory_path: str) -> bool:
        """
        Löschen eines Verzeichnisschutzes
        """
        params = {
            'directory_user': directory_user,
            'directory_path': directory_path
        }
        res = self.client.request('delete_directoryprotection', params)
        return res.get('ReturnString') == 'TRUE'

    def update_directoryprotection(
        self, 
        directory_user: str, 
        directory_path: str, 
        directory_password: str, 
        directory_authname: str
    ) -> bool:
        """
        Bearbeiten eines Verzeichnisschutzes
        """
        params = {
            'directory_user': directory_user,
            'directory_path': directory_path,
            'directory_password': directory_password,
            'directory_authname': directory_authname
        }
        res = self.client.request('update_directoryprotection', params)
        return res.get('ReturnString') == 'TRUE'
