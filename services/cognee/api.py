"""Limit Cognee's embedding threads and install the local email index."""

import importlib
import os
import sys

from gunicorn.app.wsgiapp import WSGIApplication

# ONNX otherwise sizes its pools from all host CPUs, then spins against the
# container quota. Fastembed exposes threads, but Cognee does not pass it.
embedding = importlib.import_module('cognee.infrastructure.databases.vector.embeddings.FastembedEmbeddingEngine')


class LimitedThreadEmbedding(embedding.TextEmbedding):
    def __init__(self, *args, **kwargs):
        kwargs.setdefault('threads', int(os.environ['FASTEMBED_THREADS']))
        super().__init__(*args, **kwargs)


embedding.TextEmbedding = LimitedThreadEmbedding

from cognee.api.client import app
from email_index import install

install(app)

if __name__ == "__main__":
    sys.argv = [
        "gunicorn", "--workers", "1", "--worker-class", "uvicorn.workers.UvicornWorker",
        "--timeout", "30000", "--bind", f"127.0.0.1:{os.environ['HTTP_PORT']}",
        "--log-level", "error", "cognee.api.client:app",
    ]
    WSGIApplication().run()
