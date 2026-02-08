from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from ..client import KasClient

class BaseService:
    def __init__(self, client: 'KasClient'):
        self.client = client
