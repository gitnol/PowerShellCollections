from .base import BaseService
from typing import Dict, Any, List

class SoftwareInstallService(BaseService):
    """
    Handles Software Installation operations (e.g. installing WordPress).
    """

    def get_softwareinstall(self, software_lang: str = "de") -> List[Dict[str, Any]]:
        """
        Auslesen der verfügbaren Pakete für die automatische Softwareinstallation
        """
        params = {'software_lang': software_lang}
        res = self.client.request('get_softwareinstall', params)
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return []

    def add_softwareinstall(
        self, 
        software_id: str, 
        domain_name: str, 
        software_admin_mail: str, 
        software_database: str, 
        software_database_prefix: str = None, 
        software_lang: str = "de"
    ) -> str:
        """
        Installation eines verfügbaren Softwarepaketes
        """
        params = {
            'software_id': software_id,
            'domain_name': domain_name,
            'software_admin_mail': software_admin_mail,
            'software_database': software_database,
            'software_lang': software_lang
        }
        if software_database_prefix:
            params['software_database_prefix'] = software_database_prefix
            
        res = self.client.request('add_softwareinstall', params)
        return res.get('ReturnInfo', 'TRUE')

    def delete_softwareinstall(self, installation_id: str) -> bool:
        """
        Löschen einer Softwareinstallation
        """
        params = {'installation_id': installation_id}
        res = self.client.request('delete_softwareinstall', params)
        return res.get('ReturnString') == 'TRUE'
