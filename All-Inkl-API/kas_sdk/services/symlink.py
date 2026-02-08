from .base import BaseService
from typing import Dict, Any, List

class SymlinkService(BaseService):
    """
    Handles Symlink (Link) operations.
    """

    def get_symlinks(self) -> List[Dict[str, Any]]:
        """
        List symlinks.
        """
        res = self.client.request('get_symlinks', {})
        if res and 'ReturnInfo' in res:
            return res['ReturnInfo']
        return []

    def add_symlink(self, symlink_source: str, symlink_target: str) -> str:
        """
        Add a symlink.

        Args:
            symlink_source (str): Source path.
            symlink_target (str): Target path.
        """
        params = {
            'symlink_source': symlink_source,
            'symlink_target': symlink_target
        }
        res = self.client.request('add_symlink', params)
        return res.get('ReturnInfo', 'TRUE')

    def delete_symlink(self, symlink_id: str) -> bool:
        """
        Delete a symlink.
        """
        params = {'symlink_id': symlink_id}
        res = self.client.request('delete_symlink', params)
        return res.get('ReturnString') == 'TRUE'
