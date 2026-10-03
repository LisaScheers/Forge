import unittest

from email_filter import clean_body, exclusion, parse_messages


def message(**overrides):
    return dict(subject='Hello', body='Useful correspondence.', attachments='(none)', to='lisa@example.com', scope='personal') | overrides


class EmailFilterTests(unittest.TestCase):
    def test_optional_original_date_and_folded_recipients_are_preserved(self):
        text = '## Useful message\nSent: None; received: not separately exported\nOriginal Date header: Fri, 1 Jan 2021 12:00:00 +0000\nFrom: Person <person@example.com>\nTo: lisa@example.com,\n second@example.com\nCc: (none)\nMailbox: Inbox\nMessage-ID: <a@example.com>\nSource: message://a\nAttachments (contents excluded): report.pdf\n\nEvidence body.\n\n---\n'
        parsed = list(parse_messages(text, 'source-id', 'personal-email-inbox'))
        self.assertEqual(len(parsed), 1)
        self.assertEqual(parsed[0]['original_date'], 'Fri, 1 Jan 2021 12:00:00 +0000')
        self.assertIn('second@example.com', parsed[0]['to'])
        self.assertEqual(parsed[0]['body'].strip(), 'Evidence body.')

    def test_incomplete_header_fails_instead_of_losing_a_message(self):
        with self.assertRaises(ValueError):
            list(parse_messages('## Important\nSent: None\nFrom: Person\nBody', 'id', 'personal-email-inbox'))

    def test_invoice_with_unsubscribe_footer_is_retained(self):
        self.assertIsNone(exclusion(message(subject='Your invoice 123', body='Amount due €45. Unsubscribe here.')))

    def test_corporate_benefit_in_newsletter_is_retained(self):
        self.assertIsNone(exclusion(message(subject='Company nieuwsbrief', body='Employee insurance policy benefit changed.', scope='work')))

    def test_human_reply_is_retained(self):
        self.assertIsNone(exclusion(message(subject='Re: Our meeting', body='Yes, see you tomorrow. Unsubscribe footer.')))

    def test_marketing_is_excluded(self):
        self.assertEqual(exclusion(message(subject='Shop now: 30% discount', body='Unsubscribe.')), 'marketing_or_broadcast')

    def test_attachment_evidence_is_retained(self):
        self.assertIsNone(exclusion(message(body='[No text body in export; see original email and listed attachments.]', attachments='contract.pdf')))

    def test_blank_body_notice_with_export_whitespace_is_excluded(self):
        self.assertEqual(exclusion(message(body='\n\n[No text body in export; see original email and listed attachments.]\n')), 'empty_or_attachment_only_notice')

    def test_tracking_url_is_unwrapped_without_secrets(self):
        cleaned = clean_body('Read https://example.safelinks.protection.outlook.com/?url=https%3A%2F%2Fexample.com%2Fpolicy%3Ftracking%3Dsecret&data=secret', 'Policy')
        self.assertIn('https://example.com/policy', cleaned)
        self.assertNotIn('secret', cleaned)

    def test_short_reply_keeps_quoted_evidence(self):
        self.assertIn('Earlier evidence', clean_body('Yes.\nOn Monday, someone wrote:\nEarlier evidence.', 'Re: Evidence'))


if __name__ == '__main__':
    unittest.main()
