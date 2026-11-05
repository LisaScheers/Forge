CREATE DATABASE IF NOT EXISTS ai_usage;

CREATE TABLE IF NOT EXISTS ai_usage.chunks
(
    capture_id String,
    ordinal UInt64,
    content_b64 String
)
ENGINE = ReplacingMergeTree
ORDER BY (capture_id, ordinal);

CREATE TABLE IF NOT EXISTS ai_usage.files
(
    file_name String,
    capture_id String,
    version UInt64,
    observed_at DateTime64(3, 'UTC'),
    bytes UInt64,
    chunk_count UInt64
)
ENGINE = ReplacingMergeTree(version)
ORDER BY file_name;

CREATE TABLE IF NOT EXISTS ai_usage.usage_observations
(
    capture_id String,
    ordinal UInt64,
    response_key String,
    model String,
    usage_json String,
    tokens Map(String, UInt64)
)
ENGINE = ReplacingMergeTree
ORDER BY (capture_id, ordinal);

-- A manifest appears only after every chunk and usage observation is acknowledged.
-- FINAL also makes retries idempotent before background merges run.
CREATE OR REPLACE VIEW ai_usage.requests AS
SELECT f.file_name, f.capture_id, f.observed_at, f.bytes,
       arrayStringConcat(arrayMap(x -> base64Decode(x.2),
           arraySort(x -> x.1, groupArray((c.ordinal, c.content_b64))))) AS transcript
FROM ai_usage.files AS f FINAL
INNER JOIN ai_usage.chunks AS c FINAL ON f.capture_id = c.capture_id
GROUP BY f.file_name, f.capture_id, f.observed_at, f.bytes, f.chunk_count
HAVING count() = f.chunk_count;

CREATE OR REPLACE VIEW ai_usage.usage_events AS
SELECT f.file_name, f.observed_at, u.*
FROM ai_usage.files AS f FINAL
INNER JOIN ai_usage.usage_observations AS u FINAL ON f.capture_id = u.capture_id;

-- Streaming counters may arrive in several cumulative observations. Keep each
-- counter once per upstream response/attempt. Do not sum cached/reasoning subsets.
CREATE OR REPLACE VIEW ai_usage.token_counts AS
SELECT file_name, response_key, token_category, max(token_value) AS token_count
FROM ai_usage.usage_events
ARRAY JOIN mapKeys(tokens) AS token_category, mapValues(tokens) AS token_value
GROUP BY file_name, response_key, token_category;
