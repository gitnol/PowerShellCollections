from .base import BaseService
from typing import Dict, Any, Optional, List

class DnsService(BaseService):
    """
    Handles DNS operations.
    Enforces quirks:
    - rule #2: Trailing dot on zone_host for ADD
    - rule #3: No zone_host for UPDATE
    """

    def get_dns_settings(self, zone_host: str, record_id: str = None) -> List[Dict[str, Any]]:
        """
        Auslesen der DNS Einträge
        """
        params = {'zone_host': zone_host}
        if record_id:
            params['record_id'] = record_id
            
        res = self.client.request('get_dns_settings', params)
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return []

    def add_dns_settings(
        self, 
        zone_host: str, 
        record_type: str, 
        record_name: str, 
        record_data: str, 
        record_aux: str = "0"
    ) -> str:
        """
        Anlegen eines DNS Eintrages
        """
        if not zone_host.endswith('.'):
            zone_host += '.'

        params = {
            'zone_host': zone_host,
            'record_type': record_type,
            'record_name': record_name,
            'record_data': record_data,
            'record_aux': record_aux
        }
        
        res = self.client.request('add_dns_settings', params)
        # Returns ReturnString=TRUE and often ReturnInfo=NEW_ID
        if res.get('ReturnString') == 'TRUE':
             return res.get('ReturnInfo', 'TRUE')
        
        return res.get('ReturnString', 'FALSE')

    def update_dns_settings(
        self, 
        record_id: str, 
        record_name: str = None, 
        record_data: str = None, 
        record_aux: str = None
    ) -> bool:
        """
        Bearbeiten eines DNS Eintrages
        """
        params = {'record_id': record_id}
        
        if record_name is not None: params['record_name'] = record_name
        if record_data is not None: params['record_data'] = record_data
        if record_aux is not None: params['record_aux'] = record_aux
        
        res = self.client.request('update_dns_settings', params)

        if res.get('ReturnString') == 'TRUE':
            return True
        
        # Handle "nothing_to_do" as success
        if 'nothing_to_do' in res.get('Error', ''):
            return True
            
        return False

    def delete_dns_settings(self, record_id: str) -> bool:
        """
        Löschen eines DNS Eintrages
        """
        params = {'record_id': record_id}
        res = self.client.request('delete_dns_settings', params)
        return res.get('ReturnString') == 'TRUE'

    def reset_dns_settings(self, zone_host: str, nameserver: str = "ns5.kasserver.com") -> bool:
        """
        Zurücksetzen der DNS Einstellungen
        """
        params = {
            'zone_host': zone_host,
            'nameserver': nameserver
        }
        res = self.client.request('reset_dns_settings', params)
        return res.get('ReturnString') == 'TRUE'
