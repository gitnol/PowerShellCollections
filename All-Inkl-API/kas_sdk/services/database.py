from .base import BaseService
from typing import Dict, Any, List

class DatabaseService(BaseService):
    """
    Handles MySQL Database operations.
    """

    def get_databases(self, database_login: str = None) -> List[Dict[str, Any]]:
        """
        Auslesen der Datenbanken
        """
        params = {}
        if database_login:
            params['database_login'] = database_login

        res = self.client.request('get_databases', params)
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return []

    def add_database(
        self,
        database_password: str,
        database_comment: str,
        database_allowed_hosts: str = None
    ) -> str:
        """
        Anlegen einer Datenbank
        """
        params = {
            'database_password': database_password,
            'database_comment': database_comment,
        }
        if database_allowed_hosts is not None:
            params['database_allowed_hosts'] = database_allowed_hosts
        res = self.client.request('add_database', params)
        return res.get('ReturnInfo', 'TRUE')

    def delete_database(self, database_login: str) -> bool:
        """
        Löschen einer Datenbank
        """
        params = {'database_login': database_login}
        res = self.client.request('delete_database', params)
        return res.get('ReturnString') == 'TRUE'

    def update_database(
        self,
        database_login: str,
        database_new_password: str = None,
        database_comment: str = None,
        database_allowed_hosts: str = None
    ) -> bool:
        """
        Bearbeiten der Datenbankeinstellungen
        """
        params = {'database_login': database_login}

        optional_params = {
            'database_new_password': database_new_password,
            'database_comment': database_comment,
            'database_allowed_hosts': database_allowed_hosts
        }

        for k, v in optional_params.items():
            if v is not None:
                params[k] = v

        res = self.client.request('update_database', params)
        return res.get('ReturnString') == 'TRUE'
