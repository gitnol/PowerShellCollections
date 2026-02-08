from .base import BaseService
from typing import Dict, Any

class SessionService(BaseService):
    """
    Handles Session operations (KAS SSO).
    """

    def add_session(self, session_lifetime: int = 1800, session_update_lifetime: str = "N") -> str:
        """
        Create a new KAS session token.

        Args:
            session_lifetime (int): Seconds valid.
            session_update_lifetime (str): 'Y'/'N' - update on activity?
        
        Returns:
            str: The Session ID (KasSessionId) to be used in URLs.
        """
        params = {
            'session_lifetime': session_lifetime,
            'session_update_lifetime': session_update_lifetime
        }
        res = self.client.request('add_session', params)
        return res.get('ReturnInfo', 'TRUE')
