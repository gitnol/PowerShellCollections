from .base import BaseService
from typing import Dict, Any, List

class StatisticService(BaseService):
    """
    Handles Statistic operations.
    """

    def get_space(
        self,
        show_subaccounts: str = None,
        show_details: str = None
    ) -> Any:
        """
        Get webspace usage.

        Args:
            show_subaccounts (str): 'Y'|'N' - show sub-account usage only (optional).
            show_details (str): 'Y'|'N' - include mailbox/database details (optional).
        """
        params = {}
        if show_subaccounts is not None:
            params['show_subaccounts'] = show_subaccounts
        if show_details is not None:
            params['show_details'] = show_details
        res = self.client.request('get_space', params)
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return {}

    def get_space_usage(self, directory: str) -> Any:
        """
        Get usage for a specific directory.
        """
        params = {'directory': directory}
        res = self.client.request('get_space_usage', params)
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return {}

    def get_traffic(self, year: int = None, month: int = None) -> Any:
        """
        Get traffic usage.

        Args:
            year (int): Year (optional, default current year).
            month (int): Month (optional, default current month).
        """
        params = {}
        if year is not None:
            params['year'] = year
        if month is not None:
            params['month'] = month
        res = self.client.request('get_traffic', params)
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return {}
