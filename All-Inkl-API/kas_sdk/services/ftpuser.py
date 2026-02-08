from .base import BaseService
from typing import Dict, Any, List

class FtpUserService(BaseService):
    """
    Handles FTP User operations.
    """

    def get_ftpusers(self, ftp_login: str = None) -> List[Dict[str, Any]]:
        """
        Auslesen der FTP Benutzer
        """
        params = {}
        if ftp_login:
            params['ftp_login'] = ftp_login
            
        res = self.client.request('get_ftpusers', params)
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return []

    def add_ftpuser(
        self, 
        ftp_password: str, 
        ftp_comment: str, 
        ftp_path: str = "/", 
        ftp_permission_read: str = "Y", 
        ftp_permission_write: str = "Y", 
        ftp_permission_list: str = "Y", 
        ftp_virus_clamav: str = "Y"
    ) -> str:
        """
        Anlegen eines FTP Benutzers
        """
        params = {
            'ftp_password': ftp_password,
            'ftp_comment': ftp_comment,
            'ftp_path': ftp_path,
            'ftp_permission_read': ftp_permission_read,
            'ftp_permission_write': ftp_permission_write,
            'ftp_permission_list': ftp_permission_list,
            'ftp_virus_clamav': ftp_virus_clamav
        }
            
        res = self.client.request('add_ftpuser', params)
        return res.get('ReturnInfo', 'TRUE')

    def delete_ftpuser(self, ftp_login: str) -> bool:
        """
        Löschen eines FTP Benutzers
        """
        params = {'ftp_login': ftp_login}
        res = self.client.request('delete_ftpuser', params)
        return res.get('ReturnString') == 'TRUE'

    def update_ftpuser(
        self, 
        ftp_login: str, 
        ftp_new_password: str = None,
        ftp_path: str = None,
        ftp_comment: str = None,
        ftp_permission_read: str = None,
        ftp_permission_write: str = None,
        ftp_permission_list: str = None,
        ftp_virus_clamav: str = None
    ) -> bool:
        """
        Bearbeiten eines FTP Benutzers
        """
        params = {'ftp_login': ftp_login}
        
        optional_params = {
            'ftp_new_password': ftp_new_password,
            'ftp_path': ftp_path,
            'ftp_comment': ftp_comment,
            'ftp_permission_read': ftp_permission_read,
            'ftp_permission_write': ftp_permission_write,
            'ftp_permission_list': ftp_permission_list,
            'ftp_virus_clamav': ftp_virus_clamav
        }
        
        for k, v in optional_params.items():
            if v is not None:
                params[k] = v
                
        res = self.client.request('update_ftpuser', params)
        return res.get('ReturnString') == 'TRUE'
