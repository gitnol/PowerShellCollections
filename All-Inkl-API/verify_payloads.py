import unittest
from unittest.mock import MagicMock, patch
import json
import xml.etree.ElementTree as ET
from kas_sdk import KasClient

class TestKasSdkPayloads(unittest.TestCase):
    
    @patch('kas_sdk.client.requests.post')
    def test_dns_add_record_payload(self, mock_post):
        # Setup specific response
        mock_post.return_value.content = b'<root><return><item><key>ReturnString</key><value>TRUE</value></item></return></root>'
        
        client = KasClient('user', 'pass')
        # Call with explicit strings as per new SDK contract
        client.dns.add_dns_settings(
            zone_host='example.com', 
            record_type='A', 
            record_name='test', 
            record_data='1.2.3.4', 
            record_aux="10"
        )
        
        # Verify payload
        call_args = mock_post.call_args
        data = call_args[1]['data']
        root = ET.fromstring(data)
        json_str = root.find('.//{http://schemas.xmlsoap.org/soap/envelope/}Body//{urn:xmethods-delayed-quotes}KasApi/KasRequest').text
        payload = json.loads(json_str)
        
        params = payload['KasRequestParams']
        self.assertEqual(params['record_aux'], "10", "record_aux should be passed as string '10'")
        self.assertEqual(params['zone_host'], "example.com.", "Trailing dot should be appended by SDK")

    @patch('kas_sdk.client.requests.post')
    def test_dns_update_params_clean(self, mock_post):
        mock_post.return_value.content = b'<root><return><item><key>ReturnString</key><value>TRUE</value></item></return></root>'
        
        client = KasClient('user', 'pass')
        
        client.dns.update_dns_settings(record_id='123', record_data='1.2.3.4')
        
        call_args = mock_post.call_args
        data = call_args[1]['data']
        root = ET.fromstring(data)
        json_str = root.find('.//{http://schemas.xmlsoap.org/soap/envelope/}Body//{urn:xmethods-delayed-quotes}KasApi/KasRequest').text
        payload = json.loads(json_str)
        params = payload['KasRequestParams']
        
        self.assertIn('record_id', params)
        self.assertIn('record_data', params)
        self.assertNotIn('record_name', params, "None values should be excluded")
        self.assertNotIn('zone_host', params, "zone_host should not be here")

    @patch('kas_sdk.client.requests.post')
    def test_cronjob_params(self, mock_post):
        mock_post.return_value.content = b'<root><return><item><key>ReturnString</key><value>TRUE</value></item></return></root>'
        client = KasClient('user', 'pass')
        
        # user must provide strings now for times
        client.cronjob.add_cronjob(
            protocol='http',
            http_url='http://foo.bar', 
            cronjob_comment="Test Cron",
            minute="5", 
            hour='*', 
            day_of_month='*', 
            month='*', 
            day_of_week='*'
        )
        
        call_args = mock_post.call_args
        data = call_args[1]['data']
        root = ET.fromstring(data)
        json_str = root.find('.//{http://schemas.xmlsoap.org/soap/envelope/}Body//{urn:xmethods-delayed-quotes}KasApi/KasRequest').text
        payload = json.loads(json_str)
        params = payload['KasRequestParams']
        
        self.assertEqual(params['minute'], "5", "Minute param check")
        self.assertEqual(params['protocol'], "http", "Protocol param check")

    @patch('kas_sdk.client.requests.post')
    def test_dkim_settings(self, mock_post):
        mock_post.return_value.content = b'<root><return><item><key>ReturnString</key><value>TRUE</value></item></return></root>'
        client = KasClient('user', 'pass')
        
        client.dkim.update_dkim(dkim_domain='example.com', dkim_active='Y')
        
        call_args = mock_post.call_args
        data = call_args[1]['data']
        root = ET.fromstring(data)
        json_str = root.find('.//{http://schemas.xmlsoap.org/soap/envelope/}Body//{urn:xmethods-delayed-quotes}KasApi/KasRequest').text
        payload = json.loads(json_str)
        params = payload['KasRequestParams']
        
        self.assertEqual(params['dkim_domain'], 'example.com')
        self.assertEqual(params['dkim_active'], 'Y')

if __name__ == '__main__':
    unittest.main()
