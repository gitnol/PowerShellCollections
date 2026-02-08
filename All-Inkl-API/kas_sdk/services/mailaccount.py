from .base import BaseService
from typing import Dict, Any, List

class MailAccountService(BaseService):
    """
    Handles MailAccount operations.
    """

    def get_mailaccounts(self, mail_login: str = None) -> List[Dict[str, Any]]:
        params = {}
        if mail_login:
            params['mail_login'] = mail_login
        res = self.client.request('get_mailaccounts', params)
        if res and 'ReturnInfo' in res:
             return res['ReturnInfo']
        return []

    def add_mailaccount(
        self, 
        mail_password: str, 
        local_part: str, 
        domain_part: str, 
        webmail_autologin: str = 'Y',
        responder: str = 'N',
        mail_responder_content_type: str = 'text',
        mail_responder_displayname: str = '',
        responder_text: str = '',
        copy_adress: str = '',
        mail_sender_alias: str = '',
        mail_xlist_enabled: str = 'Y',
        mail_xlist_sent: str = 'Sent',
        mail_xlist_drafts: str = 'Drafts',
        mail_xlist_trash: str = 'Trash',
        mail_xlist_spam: str = 'Spam',
        mail_xlist_archiv: str = 'Archiv',
    ) -> str:
        """
        Add a new mail account.
        """
        params = {
            'mail_password': mail_password,
            'local_part': local_part,
            'domain_part': domain_part,
            'webmail_autologin': webmail_autologin,
            'responder': responder,
            'mail_responder_content_type': mail_responder_content_type,
            'mail_responder_displayname': mail_responder_displayname,
            'responder_text': responder_text,
            'copy_adress': copy_adress,
            'mail_sender_alias': mail_sender_alias,
            'mail_xlist_enabled': mail_xlist_enabled,
            'mail_xlist_sent': mail_xlist_sent,
            'mail_xlist_drafts': mail_xlist_drafts,
            'mail_xlist_trash': mail_xlist_trash,
            'mail_xlist_spam': mail_xlist_spam,
            'mail_xlist_archiv': mail_xlist_archiv,
        }
        res = self.client.request('add_mailaccount', params)
        return res.get('ReturnInfo', 'TRUE')

    def delete_mailaccount(self, mail_login: str) -> bool:
        params = {'mail_login': mail_login}
        res = self.client.request('delete_mailaccount', params)
        return res.get('ReturnString') == 'TRUE'

    def update_mailaccount(
        self, 
        mail_login: str, 
        mail_new_password: str = None,
        webmail_autologin: str = None,
        responder: str = None,
        mail_responder_content_type: str = None,
        mail_responder_displayname: str = None,
        responder_text: str = None,
        copy_adress: str = None,
        is_active: str = None,
        mail_sender_alias: str = None,
        mail_xlist_enabled: str = None,
        mail_xlist_sent: str = None,
        mail_xlist_drafts: str = None,
        mail_xlist_trash: str = None,
        mail_xlist_spam: str = None,
        mail_xlist_archiv: str = None,
    ) -> bool:
        params = {'mail_login': mail_login}
        
        optional_params = {
            'mail_new_password': mail_new_password,
            'webmail_autologin': webmail_autologin,
            'responder': responder,
            'mail_responder_content_type': mail_responder_content_type,
            'mail_responder_displayname': mail_responder_displayname,
            'responder_text': responder_text,
            'copy_adress': copy_adress,
            'is_active': is_active,
            'mail_sender_alias': mail_sender_alias,
            'mail_xlist_enabled': mail_xlist_enabled,
            'mail_xlist_sent': mail_xlist_sent,
            'mail_xlist_drafts': mail_xlist_drafts,
            'mail_xlist_trash': mail_xlist_trash,
            'mail_xlist_spam': mail_xlist_spam,
            'mail_xlist_archiv': mail_xlist_archiv,
        }
        
        for k, v in optional_params.items():
            if v is not None:
                params[k] = v

        res = self.client.request('update_mailaccount', params)
        return res.get('ReturnString') == 'TRUE'
