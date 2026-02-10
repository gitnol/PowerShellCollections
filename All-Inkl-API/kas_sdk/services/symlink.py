from .base import BaseService
from typing import Dict, Any, List

class SymlinkService(BaseService):
    """
    Handles Symlink (Link) operations.
    """

    def add_symlink(self, symlink_name: str, symlink_target: str) -> str:
        """
        Add a symlink.

        Args:
            symlink_name (str): The symlink name (source path).
            symlink_target (str): The symlink target (destination path).
        """
        params = {
            'symlink_name': symlink_name,
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
