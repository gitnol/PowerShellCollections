from .base import BaseService
from typing import Dict, Any, List

class StatisticService(BaseService):
    """
    Handles Statistic operations.
    """

    def get_space(self) -> Dict[str, Any]:
        """
        Get webspace usage.
        """
        res = self.client.request('get_space', {})
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return {}

    def get_traffic(self) -> Dict[str, Any]:
        """
        Get traffic usage.
        """
        res = self.client.request('get_traffic', {})
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return {}
