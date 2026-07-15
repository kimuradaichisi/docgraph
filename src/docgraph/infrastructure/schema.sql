-- DocGraph SQLite schema v1
CREATE TABLE IF NOT EXISTS schema_version (
    version    INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS documents (
    id         TEXT PRIMARY KEY,
    path       TEXT NOT NULL UNIQUE,
    hash       TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    indexed_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_documents_hash ON documents(hash);

CREATE TABLE IF NOT EXISTS headings (
    id     INTEGER PRIMARY KEY AUTOINCREMENT,
    doc_id TEXT NOT NULL,
    level  INTEGER NOT NULL,
    text   TEXT NOT NULL,
    line   INTEGER NOT NULL,
    FOREIGN KEY (doc_id) REFERENCES documents(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_headings_doc_id ON headings(doc_id);

CREATE TABLE IF NOT EXISTS links (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    doc_id      TEXT NOT NULL,
    target_path TEXT NOT NULL,
    text        TEXT NOT NULL,
    line        INTEGER NOT NULL,
    FOREIGN KEY (doc_id) REFERENCES documents(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_links_doc_id ON links(doc_id);

CREATE TABLE IF NOT EXISTS relations (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    source_id     TEXT NOT NULL,
    target_id     TEXT NOT NULL,
    reason        TEXT NOT NULL,
    confidence    REAL NOT NULL,
    evidence_line INTEGER NOT NULL,
    FOREIGN KEY (source_id) REFERENCES documents(id) ON DELETE CASCADE,
    FOREIGN KEY (target_id) REFERENCES documents(id) ON DELETE CASCADE,
    UNIQUE (source_id, target_id, reason)
);
CREATE INDEX IF NOT EXISTS idx_relations_source ON relations(source_id);
CREATE INDEX IF NOT EXISTS idx_relations_target ON relations(target_id);

CREATE VIRTUAL TABLE IF NOT EXISTS documents_fts USING fts5(
    doc_id UNINDEXED,
    body,
    tokenize = 'unicode61 remove_diacritics 2'
);
