from .base import BaseService
from typing import Dict, Any, List

class SslService(BaseService):
    """
    Handles SSL operations.
    """

    def update_ssl(
        self,
        hostname: str = None,
        ssl_certificate_is_active: str = None,
        ssl_certificate_sni_csr: str = None,
        ssl_certificate_sni_key: str = None,
        ssl_certificate_sni_crt: str = None,
        ssl_certificate_sni_bundle: str = None,
        ssl_certificate_force_https: str = None,
        ssl_certificate_hsts_max_age: int = None,
    ) -> bool:
        """
        Update SSL settings.

        Args:
            hostname (str): The hostname to update.
            ssl_certificate_is_active (str): 'Y'|'N' (optional).
            ssl_certificate_sni_csr (str): SSL CSR (optional).
            ssl_certificate_sni_key (str): Private Key.
            ssl_certificate_sni_crt (str): Certificate.
            ssl_certificate_sni_bundle (str): CA Bundle (optional).
            ssl_certificate_force_https (str): 'Y'|'N' (optional).
            ssl_certificate_hsts_max_age (int): Seconds for HSTS (-1 to disable, optional).
        """
        params = {}

        if hostname: params['hostname'] = hostname
        if ssl_certificate_is_active: params['ssl_certificate_is_active'] = ssl_certificate_is_active
        if ssl_certificate_sni_csr: params['ssl_certificate_sni_csr'] = ssl_certificate_sni_csr
        if ssl_certificate_sni_key: params['ssl_certificate_sni_key'] = ssl_certificate_sni_key
        if ssl_certificate_sni_crt: params['ssl_certificate_sni_crt'] = ssl_certificate_sni_crt
        if ssl_certificate_sni_bundle: params['ssl_certificate_sni_bundle'] = ssl_certificate_sni_bundle
        if ssl_certificate_force_https: params['ssl_certificate_force_https'] = ssl_certificate_force_https
        if ssl_certificate_hsts_max_age is not None: params['ssl_certificate_hsts_max_age'] = ssl_certificate_hsts_max_age

        res = self.client.request('update_ssl', params)
        
        if res.get('ReturnString') == 'TRUE':
            return True
            
        # Handle "nothing_to_do" as success (common in HSTS updates)
        if 'nothing_to_do' in res.get('Error', ''):
            return True
            
        return False
