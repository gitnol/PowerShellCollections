from .base import BaseService
from typing import Dict, Any, List

class SubdomainService(BaseService):
    """
    Handles Subdomain operations.
    """

    def get_subdomains(self, subdomain_name: str = None) -> List[Dict[str, Any]]:
        """
        Auslesen der Subdomains
        """
        params = {}
        if subdomain_name:
            params['subdomain_name'] = subdomain_name

        res = self.client.request('get_subdomains', params)
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return []

    def add_subdomain(
        self,
        subdomain_name: str,
        domain_name: str,
        subdomain_path: str = None,
        redirect_status: int = None,
        statistic_version: int = None,
        statistic_language: str = None,
        php_version: str = None
    ) -> str:
        """
        Anlegen einer Subdomain
        """
        params = {
            'subdomain_name': subdomain_name,
            'domain_name': domain_name
        }
        if subdomain_path:
            params['subdomain_path'] = subdomain_path
        if redirect_status is not None:
            params['redirect_status'] = redirect_status
        if statistic_version is not None:
            params['statistic_version'] = statistic_version
        if statistic_language:
            params['statistic_language'] = statistic_language
        if php_version:
            params['php_version'] = php_version

        res = self.client.request('add_subdomain', params)
        return res.get('ReturnInfo', 'TRUE')

    def delete_subdomain(self, subdomain_name: str) -> bool:
        """
        Löschen einer Subdomain
        """
        params = {'subdomain_name': subdomain_name}
        res = self.client.request('delete_subdomain', params)
        return res.get('ReturnString') == 'TRUE'

    def update_subdomain(
        self,
        subdomain_name: str,
        subdomain_path: str = None,
        redirect_status: int = None,
        php_version: str = None,
        is_active: str = None
    ) -> bool:
        """
        Bearbeiten einer Subdomain
        """
        params = {'subdomain_name': subdomain_name}

        optional_params = {
            'subdomain_path': subdomain_path,
            'redirect_status': redirect_status,
            'php_version': php_version,
            'is_active': is_active
        }

        for k, v in optional_params.items():
            if v is not None:
                params[k] = v

        res = self.client.request('update_subdomain', params)
        return res.get('ReturnString') == 'TRUE'
