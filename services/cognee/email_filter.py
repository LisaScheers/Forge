"""Prepare a reversible, local-only email index from Cognee's stored exports.

Original uploads stay intact. Each retained message keeps its date, author,
message:// source and original data IDs; exclusions have an audit reason.
"""

import argparse
import collections
import hashlib
import html
import json
import os
from pathlib import Path
import re
import sqlite3
from urllib.parse import parse_qs, unquote, urlparse


MESSAGE = re.compile(r"(?m)^## (.*?)\nSent: ([^\n]*)\n")
URL = re.compile(r"https?://[^\s<>\[\]]+")
MARKETING = re.compile(r"\b(newsletter|nieuwsbrief|unsubscribe|uitschrijven|afmelden|sale|discount|korting|promo(?:tion)?|aanbieding|black friday|cyber monday|webinar|digest|shop now|limited.time|offre|désabonner)\b", re.I)
TRANSACTION = re.compile(r"\b(invoice|factuur|receipt|kwitantie|order (?:confirmation|number|shipped)|bestelling|betaling|payment|shipping|delivery|verzonden|payroll|loonbrief|salaris|salary|payslip|reintegration|re.integratie|arbeidsongeschikt|mutualiteit|medical|medisch|insurance|verzekering|policy|polis|claim|uitkering|attest|benefit|vergoeding|voucher|belasting|tax|appointment|afspraak|consultatie|contract|agreement|overeenkomst|support ticket|incident|security alert|data breach)\b", re.I)
AUTH_NOTICE = re.compile(r"\b(verification code|verificatiecode|one.time (?:password|code)|login code|sign.in code|password reset|reset your password|wachtwoord (?:resetten|herstellen)|bevestig je e.mail|confirm your e.mail)\b", re.I)
QUOTED_HEADER = re.compile(r"(?im)^(?:On .{5,200} wrote:|Op .{5,200} schreef .*:|Le .{5,200} écrit\s*:|[- ]{3,}Original Message[- ]{3,}|[- ]{3,}Oorspronkelijk bericht[- ]{3,}|From: .+\n(?:Sent|Date):)")


def clean_url(match):
    parsed = urlparse(html.unescape(match.group(0)))
    if parsed.hostname and parsed.hostname.endswith('safelinks.protection.outlook.com'):
        target = parse_qs(parsed.query).get('url', [''])[0]
        if target.startswith(('https://', 'http://')):
            parsed = urlparse(target)
    # Authentication and unsubscribe URLs carry secrets and have no memory value.
    if re.search(r'login|signin|sign-in|redeem|unsubscribe|/auth/|reset-password|verify', parsed.path, re.I):
        return '[account link omitted]'
    return parsed._replace(query='', fragment='', params='').geturl()


def clean_body(body, subject):
    body = html.unescape(body).replace('\xa0', ' ')
    body = re.sub(r'[\u200b-\u200f\u202a-\u202e\u2060\ufeff]', '', body)
    body = re.sub(r'(?is)<(script|style)\b.*?</\1>', '', body)
    body = re.sub(r'<[^>\n]+>', '', body)
    body = URL.sub(clean_url, body)
    body = re.sub(r'(?im)^You don.t often get email from .*(?:\nLearn why this is important)?', '', body)
    body = re.sub(r'(?im)^CAUTION: This email originated.*$', '', body)
    # A forward can contain the only copy of its evidence. Strip quoted tails
    # only from replies with substantive new text, retaining a source reference.
    quoted = QUOTED_HEADER.search(body)
    if quoted and not re.match(r'(?i)\s*(fw|fwd|doorst):', subject) and len(body[:quoted.start()].strip()) >= 120:
        body = body[:quoted.start()] + '\n[Earlier quoted correspondence omitted; see source email.]'
    body = re.sub(r'(?m)^>.*$', '', body) if not re.match(r'(?i)\s*(fw|fwd|doorst):', subject) else body
    body = re.sub(r'[ \t]+', ' ', body)
    body = re.sub(r'\n[ \t]*\n(?:[ \t]*\n)+', '\n\n', body)
    return body.strip().rstrip('-').strip()


def exclusion(message):
    subject, body = message['subject'], message['body'].strip()
    attachments = message['attachments']
    meaningful_attachment = attachments not in ('(none)', '', 'None') and not re.fullmatch(r'(?i)(?:[^,]*\.(?:jpg|png|gif|ics|asc)(?:,\s*)?)+', attachments)
    if AUTH_NOTICE.search(subject):
        return 'expired_authentication_notice'
    if re.search(r'(?i)unsubscribe|uitschrijven|list-unsubscribe', subject) or 'unsubscribe@' in message['to'].lower():
        return 'unsubscribe_request'
    if not body or body.startswith('[No text body in export;'):
        return None if meaningful_attachment else 'empty_or_attachment_only_notice'
    if re.fullmatch(r'(?i)(?:re:\s*)?(test|testing|testje)?', subject.strip()) and len(body) < 100:
        return 'test_message'
    if TRANSACTION.search(subject):
        return None
    # Human replies remain even when a quoted footer says unsubscribe.
    if re.match(r'(?i)\s*(re|fw|fwd|doorst):', subject):
        return None
    if MARKETING.search(subject + '\n' + body):
        # Corporate newsletters may contain concrete employee benefits.
        if message['scope'] == 'work' and TRANSACTION.search(body):
            return None
        if MARKETING.search(subject) or re.search(r'(?i)unsubscribe|uitschrijven|afmelden|désabonner', body):
            return 'marketing_or_broadcast'
    return None


def parse_messages(text, source_id, source_name):
    headers = list(MESSAGE.finditer(text))
    scope = 'work' if source_name.startswith('work-') else 'personal'
    for index, header in enumerate(headers):
        subject, sent = header.groups()
        end = headers[index + 1].start() if index + 1 < len(headers) else len(text)
        block = text[header.end():end]
        marker = re.search(r'(?m)^Attachments \(contents excluded\): ([^\n]*)\n', block)
        if marker is None:
            raise ValueError(f'Unrecognized message header in {source_name}')
        fields = {}
        current = None
        for line in block[:marker.start()].splitlines():
            key, separator, value = line.partition(': ')
            if separator and key in ('Original Date header', 'From', 'To', 'Cc', 'Mailbox', 'Message-ID', 'Source'):
                fields[key] = value
                current = key
            elif current:
                fields[current] += ' ' + line.strip()
        if not {'From', 'To', 'Cc', 'Mailbox', 'Message-ID', 'Source'} <= fields.keys():
            raise ValueError(f'Incomplete message header in {source_name}')
        body = block[marker.end():]
        body = re.sub(r'\n\n---\s*$', '', body)
        yield dict(subject=html.unescape(subject), sent=sent.split('; received:', 1)[0], original_date=fields.get('Original Date header'), sender=fields['From'], to=fields['To'], cc=fields['Cc'], mailbox=fields['Mailbox'], message_id=fields['Message-ID'].strip('<> '), source=fields['Source'], attachments=marker.group(1), body=body, scope=scope, source_ids=[source_id], raw_bytes=end-header.start())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--storage', type=Path, default=Path('/srv/disks/projects/cognee'))
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    os.umask(0o077)
    args.output.mkdir(parents=True, exist_ok=False)
    conn = sqlite3.connect(f'file:{args.storage}/system/databases/cognee_db?mode=ro', uri=True)
    rows = conn.execute("select id,name,raw_data_location from data where name like '%email%' order by created_at").fetchall()
    messages = {}
    duplicates = 0
    original_bytes = 0
    sources = []
    for source_id, name, location in rows:
        file_path = Path(unquote(urlparse(location).path).replace('/cognee-storage/', str(args.storage) + '/', 1))
        file_path.resolve().relative_to((args.storage / 'data').resolve())
        raw = file_path.read_bytes()
        if not raw.startswith((b'# Lisa work email corpus', b'# Lisa personal email corpus')):
            continue
        original_bytes += len(raw)
        sources.append({'id': source_id, 'name': name, 'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw)})
        for message in parse_messages(raw.decode('utf-8'), source_id, name):
            key = message['message_id'] or hashlib.sha256((message['sender'] + message['subject'] + message['sent'] + message['body']).encode()).hexdigest()
            if key in messages:
                duplicates += 1
                existing = messages[key]
                ids = sorted(set(existing['source_ids'] + message['source_ids']))
                if len(message['body']) > len(existing['body']):
                    messages[key] = message
                messages[key]['source_ids'] = ids
            else:
                messages[key] = message
    reasons = collections.Counter()
    kept_bytes = 0
    kept = 0
    retained_by_scope = collections.Counter()
    with (args.output / 'cleaned.jsonl').open('w') as cleaned, (args.output / 'excluded.jsonl').open('w') as excluded:
        for message in messages.values():
            reason = exclusion(message)
            if reason:
                reasons[reason] += 1
                excluded.write(json.dumps({k: message[k] for k in ('message_id', 'source', 'source_ids', 'subject', 'sent', 'scope')} | {'reason': reason}) + '\n')
                continue
            message['body'] = clean_body(message['body'], message['subject'])
            cleaned.write(json.dumps(message, ensure_ascii=False) + '\n')
            kept += 1
            retained_by_scope[message['scope']] += 1
            kept_bytes += len(message['body'].encode())
    report = dict(source_uploads=len(sources), original_bytes=original_bytes, unique_messages=len(messages), duplicate_messages=duplicates, retained_messages=kept, retained_body_bytes=kept_bytes, retained_by_scope=dict(retained_by_scope), excluded_by_reason=dict(reasons), sources=sources)
    (args.output / 'report.json').write_text(json.dumps(report, indent=2))
    print(json.dumps({k: v for k, v in report.items() if k != 'sources'}))


if __name__ == '__main__':
    main()
