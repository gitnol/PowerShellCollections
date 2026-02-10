from .base import BaseService
from typing import Dict, Any, List

class SoftwareInstallService(BaseService):
    """
    Handles Software Installation operations (e.g. installing WordPress).
    """

    def get_softwareinstall(self, software_id: str = None) -> List[Dict[str, Any]]:
        """
        Auslesen der verfügbaren Pakete für die automatische Softwareinstallation
        """
        params = {}
        if software_id is not None:
            params['software_id'] = software_id
        res = self.client.request('get_softwareinstall', params)
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return []

    def add_softwareinstall(
        self,
        software_id: str,
        software_database: str,
        software_database_password: str,
        software_hostname: str,
        software_path: str,
        software_admin_mail: str,
        software_admin_user: str,
        software_admin_pass: str,
        software_install_example_data: str = None,
        language: str = "de"
    ) -> str:
        """
        Installation eines verfügbaren Softwarepaketes
        """
        params = {
            'software_id': software_id,
            'software_database': software_database,
            'software_database_password': software_database_password,
            'software_hostname': software_hostname,
            'software_path': software_path,
            'software_admin_mail': software_admin_mail,
            'software_admin_user': software_admin_user,
            'software_admin_pass': software_admin_pass,
            'language': language,
        }
        if software_install_example_data is not None:
            params['software_install_example_data'] = software_install_example_data

        res = self.client.request('add_softwareinstall', params)
        return res.get('ReturnInfo', 'TRUE')

    def delete_softwareinstall(self, installation_id: str) -> bool:
        """
        Löschen einer Softwareinstallation
        """
        params = {'installation_id': installation_id}
        res = self.client.request('delete_softwareinstall', params)
        return res.get('ReturnString') == 'TRUE'
