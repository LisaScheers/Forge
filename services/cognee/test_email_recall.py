import json
import unittest

from email_recall import email_sources


class EmailRecallTests(unittest.TestCase):
    def test_later_chunk_keeps_date_and_original_source(self):
        result = {'text': 'Later paragraph', 'raw': {'document_name': 'Invoice', 'chunk_index': 4, 'external_metadata': json.dumps({'source_uri': 'message://original', 'sent_date': '2024-01-01'})}}
        rendered = email_sources([result])[0]['text']
        self.assertIn('Sent: 2024-01-01', rendered)
        self.assertIn('Source: message://original', rendered)
        self.assertTrue(rendered.endswith('Later paragraph'))
        self.assertEqual(result['text'], 'Later paragraph')

    def test_other_memory_and_malformed_metadata_are_unchanged(self):
        results = [{'text': 'Fact'}, {'text': 'Note', 'raw': {'external_metadata': '{'}}, 'Other shape']
        self.assertEqual(email_sources(results), results)

    def test_original_header_date_survives_missing_export_date(self):
        result = {'text': 'Body', 'raw': {'external_metadata': json.dumps({'source_uri': 'message://old', 'sent_date': 'None', 'original_date': 'Tue, 2 Jan 2018 09:00:00 +0100'})}}
        rendered = email_sources([result])[0]['text']
        self.assertIn('Sent: unknown', rendered)
        self.assertIn('Original Date: Tue, 2 Jan 2018 09:00:00 +0100', rendered)


if __name__ == '__main__':
    unittest.main()
