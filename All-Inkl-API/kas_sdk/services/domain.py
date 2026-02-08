from .base import BaseService
from typing import Dict, Any, List

class DomainService(BaseService):
    """
    Handles Domain operations.
    """

    def get_topleveldomains(self) -> List[Dict[str, Any]]:
        """
        Auslesen der TLDs
        """
        res = self.client.request('get_topleveldomains', {})
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return []

    def get_domains(self, domain_name: str = None) -> List[Dict[str, Any]]:
        """
        Auslesen der Domains
        """
        params = {}
        if domain_name:
            params['domain_name'] = domain_name
        res = self.client.request('get_domains', params)
        if res and 'ReturnInfo' in res:
             return res['ReturnInfo']
        return []

    def add_domain(
        self, 
        domain_name: str, 
        domain_tld: str, 
        domain_path: str = None, 
        redirect_status: int = None,
        statistic_version: int = None,
        statistic_language: str = None,
        php_version: str = None
    ) -> str:
        """
        Anlegen einer Domain
        """
        params = {
            'domain_name': domain_name,
            'domain_tld': domain_tld
        }
        
        optional_params = {
            'domain_path': domain_path,
            'redirect_status': redirect_status,
            'statistic_version': statistic_version,
            'statistic_language': statistic_language,
            'php_version': php_version
        }
        
        for k, v in optional_params.items():
            if v is not None:
                params[k] = v
            
        res = self.client.request('add_domain', params)
        return res.get('ReturnInfo', 'TRUE')

    def delete_domain(self, domain_name: str) -> bool:
        """
        Löschen einer Domain
        """
        params = {'domain_name': domain_name}
        res = self.client.request('delete_domain', params)
        return res.get('ReturnString') == 'TRUE'
 
    def update_domain(
        self, 
        domain_name: str, 
        domain_path: str = None, 
        redirect_status: int = None,
        php_version: str = None, 
        is_active: str = None
    ) -> bool:
        """
        Bearbeiten einer Domain
        """
        params = {'domain_name': domain_name}
        
        optional_params = {
            'domain_path': domain_path,
            'redirect_status': redirect_status,
            'php_version': php_version,
            'is_active': is_active
        }
        
        for k, v in optional_params.items():
            if v is not None:
                params[k] = v
            
        res = self.client.request('update_domain', params)
        return res.get('ReturnString') == 'TRUE'
        
    def move_domain(self, domain_name: str, source_account: str, target_account: str) -> bool:
        """
        Verschieben einer Domain
        """
        params = {
            'domain_name': domain_name,
            'source_account': source_account,
            'target_account': target_account
        }
        res = self.client.request('move_domain', params)
        return res.get('ReturnString') == 'TRUE'
