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
        ssl_job: str = None,          # Legacy/LE support
        ssl_account: str = None       # Legacy/LE support
    ) -> bool:
        """
        Update SSL settings. Supports both manual certificate upload/config 
        and Let's Encrypt jobs (via ssl_job).

        Args:
            hostname (str): The hostname to update (Standard API).
            ssl_certificate_is_active (str): 'Y'|'N'.
            ssl_certificate_sni_key (str): Private Key.
            ssl_certificate_sni_crt (str): Certificate.
            ssl_certificate_sni_bundle (str): CA Bundle.
            ssl_certificate_force_https (str): 'Y'|'N'.
            ssl_certificate_hsts_max_age (int): Seconds for HSTS (-1 to disable).
            ssl_job (str): LE Job (e.g. 'letsencrypt_create').
            ssl_account (str): Account for LE Job.
        """
        params = {}
        
        # Standard API params
        if hostname: params['hostname'] = hostname
        if ssl_certificate_is_active: params['ssl_certificate_is_active'] = ssl_certificate_is_active
        if ssl_certificate_sni_csr: params['ssl_certificate_sni_csr'] = ssl_certificate_sni_csr
        if ssl_certificate_sni_key: params['ssl_certificate_sni_key'] = ssl_certificate_sni_key
        if ssl_certificate_sni_crt: params['ssl_certificate_sni_crt'] = ssl_certificate_sni_crt
        if ssl_certificate_sni_bundle: params['ssl_certificate_sni_bundle'] = ssl_certificate_sni_bundle
        if ssl_certificate_force_https: params['ssl_certificate_force_https'] = ssl_certificate_force_https
        if ssl_certificate_hsts_max_age is not None: params['ssl_certificate_hsts_max_age'] = ssl_certificate_hsts_max_age
        
        # Legacy/LE params
        if ssl_job: params['ssl_job'] = ssl_job
        if ssl_account: params['ssl_account'] = ssl_account

        res = self.client.request('update_ssl', params)
        
        if res.get('ReturnString') == 'TRUE':
            return True
            
        # Handle "nothing_to_do" as success (common in HSTS updates)
        if 'nothing_to_do' in res.get('Error', ''):
            return True
            
        return False
