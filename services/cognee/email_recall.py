"""Keep email dates and sources visible in Cognee MCP's text response."""

import json


def email_sources(results):
    if not isinstance(results, list):
        return results
    enriched = []
    for result in results:
        if not isinstance(result, dict):
            enriched.append(result)
            continue
        raw = result.get('raw') or {}
        metadata = raw.get('external_metadata') if isinstance(raw, dict) else None
        if isinstance(metadata, str):
            try:
                metadata = json.loads(metadata)
            except ValueError:
                metadata = None
        if isinstance(metadata, dict) and metadata.get('source_uri') and 'sent_date' in metadata:
            context = f"Email: {raw.get('document_name', '(no subject)')}\nSent: {metadata['sent_date']}\nSource: {metadata['source_uri']}\n\n"
            result = {**result, 'text': context + result.get('text', '')}
        enriched.append(result)
    return enriched
