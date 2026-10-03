"""A deterministic email pipeline; embeds locally and never calls the LLM."""

import importlib
import json
import os
from email.utils import getaddresses
from pathlib import Path
from urllib.parse import unquote, urlparse
from uuid import NAMESPACE_URL, UUID, uuid5

from fastapi import Depends, HTTPException
from pydantic import BaseModel, Field

from cognee.infrastructure.engine import DataPoint
from cognee.modules.chunking.chunk_id import chunk_content_hash, content_chunk_id
from cognee.modules.chunking.models import DocumentChunk
from cognee.modules.data.methods import get_authorized_existing_datasets
from cognee.modules.data.methods.get_dataset_data import get_dataset_data
from cognee.modules.data.processing.document_types import TextDocument
from cognee.modules.pipelines.tasks.task import Task
from cognee.modules.pipelines import run_pipeline
from cognee.modules.pipelines.layers.pipeline_execution_mode import run_pipeline_as_background_process
from cognee.modules.users.methods import get_authenticated_user
from cognee.modules.users.models import User
from cognee.tasks.chunks import chunk_by_paragraph
from cognee.tasks.storage import add_data_points

LABEL = 'forge-email-index-v1'


class EmailAddress(DataPoint):
    name: str
    metadata: dict = {'index_fields': [], 'identity_fields': ['name']}


class EmailMessage(TextDocument):
    sender: EmailAddress | None
    recipients: list[EmailAddress]
    sent_date: str | None
    original_date: str | None
    source: str
    message_id: str
    scope: str
    mailbox: str
    attachments: str
    metadata: dict = {'index_fields': []}


async def email_chunks(data_items):
    """JSONL is an uploaded source, not a client-supplied filesystem path."""
    for data_item in data_items:
        file_path = Path(unquote(urlparse(data_item.raw_data_location).path))
        file_path.resolve().relative_to(Path('/cognee-storage/data').resolve())
        with file_path.open() as source:
            for line in source:
                message = json.loads(line)
                identity = message['message_id'] or message['source']
                document = EmailMessage(
                    id=uuid5(NAMESPACE_URL, 'forge-email:' + identity),
                    name=message['subject'] or '(no subject)',
                    raw_data_location=message['source'],
                    external_metadata=json.dumps({'source_uri': message['source'], 'sent_date': message['sent'], 'scope': message['scope'], 'source_data_ids': message['source_ids']}),
                    sender=EmailAddress(name=message['sender']) if message['sender'].strip() else None,
                    recipients=[EmailAddress(name=address.lower()) for _, address in getaddresses([message['to'], message['cc']]) if '@' in address],
                    sent_date=None if message['sent'] == 'None' else message['sent'],
                    original_date=message.get('original_date'),
                    source=message['source'], message_id=message['message_id'], scope=message['scope'],
                    mailbox=message['mailbox'], attachments=message['attachments'],
                )
                # Every returned chunk carries the context needed to distinguish
                # a dated email claim from a confirmed present-day personal fact.
                prefix = f"Email: {document.name}\nSent: {message['sent']}\nFrom: {message['sender']}\nTo: {message['to']}\nAttachments (contents excluded): {message['attachments']}\nSource: {message['source']}\n\n"
                text = prefix + message['body']
                occurrences = {}
                for index, chunk in enumerate(chunk_by_paragraph(text, 254)):
                    content_hash = chunk_content_hash(chunk['text'])
                    occurrence = occurrences.get(content_hash, 0)
                    occurrences[content_hash] = occurrence + 1
                    yield DocumentChunk(
                        id=content_chunk_id(str(document.id), content_hash, occurrence),
                        text=chunk['text'], chunk_size=chunk['chunk_size'], chunk_index=index,
                        cut_type=chunk['cut_type'], content_hash=content_hash,
                        max_chunk_tokens=254, chunker_id='forge_email_v1',
                        is_part_of=document, contains=[], document_id=str(document.id),
                        document_name=document.name,
                    )


def email_tasks():
    return [
        Task(email_chunks, needs_llm=False),
        Task(add_data_points, embed_triplets=False, task_config={'batch_size': 128}, needs_llm=False),
    ]


class IndexRequest(BaseModel):
    dataset_id: UUID
    data_ids: list[UUID] = Field(min_length=1, max_length=100)


def install(app):
    archive_file = os.environ.get('COGNEE_EMAIL_ARCHIVE_IDS')
    if not archive_file:
        return
    archived_ids = {UUID(item) for item in json.loads(Path(archive_file).read_text())} if Path(archive_file).is_file() else set()
    pipeline = importlib.import_module('cognee.modules.pipelines.operations.pipeline')
    original_run = pipeline.run_pipeline_per_dataset

    async def route_email_data(dataset, user, tasks=None, data=None, pipeline_name='custom_pipeline', **kwargs):
        if pipeline_name == 'cognify_pipeline':
            data = data if data is not None else await get_dataset_data(dataset.id)
            data = [item for item in data if item.id not in archived_ids]
            standard_tasks = tasks
            local_tasks = email_tasks()

            def select_tasks(item):
                if item.label == LABEL:
                    return local_tasks
                return standard_tasks(item) if callable(standard_tasks) else standard_tasks

            tasks = select_tasks
            if not data:
                raise ValueError('Raw email exports are archived; use their cleaned local index.')
        async for event in original_run(dataset=dataset, user=user, tasks=tasks, data=data, pipeline_name=pipeline_name, **kwargs):
            yield event

    pipeline.run_pipeline_per_dataset = route_email_data

    @app.post('/api/v1/email-index')
    async def start_index(payload: IndexRequest, user: User = Depends(get_authenticated_user)):
        authorized = await get_authorized_existing_datasets([payload.dataset_id], 'write', user)
        if not authorized:
            raise HTTPException(403, 'Dataset write permission required')
        requested = set(payload.data_ids)
        items = [item for item in await get_dataset_data(payload.dataset_id) if item.id in requested]
        if len(items) != len(requested) or any(item.label != LABEL for item in items):
            raise HTTPException(400, 'Every requested item must be a labeled email-index upload in this dataset')
        return await run_pipeline_as_background_process(
            pipeline=run_pipeline,
            tasks=email_tasks(), data=items, datasets=[payload.dataset_id], user=user,
            pipeline_name='cognify_pipeline', incremental_loading=True, data_cache=True,
            data_per_batch=1, skip_connection_test=True,
        )
