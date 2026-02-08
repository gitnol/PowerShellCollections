from .base import BaseService

class ChownService(BaseService):
    """
    Handles Chown (Owner Reset) operations.
    """

    def update_chown(self, chown_path: str, chown_user: str, recursive: str = "N") -> bool:
        """
        Bearbeiten der Besitzrechte
        """
        params = {
            'chown_path': chown_path,
            'chown_user': chown_user,
            'recursive': recursive
        }
        res = self.client.request('update_chown', params)
        return res.get('ReturnString') == 'TRUE'
