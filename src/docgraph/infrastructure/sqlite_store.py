"""SqliteStore - implements repositories on top of SQLite."""
import sqlite3
from pathlib import Path


class SqliteStore:
    def __init__(self, db_path: Path) -> None:
        self._db_path = db_path
        self._conn = sqlite3.connect(str(db_path))
        self._conn.execute("PRAGMA foreign_keys = ON")
        self._apply_schema()

    def _apply_schema(self) -> None:
        schema_path = Path(__file__).parent / "schema.sql"
        with self._conn:
            self._conn.executescript(schema_path.read_text(encoding="utf-8"))

    # TODO: implement DocumentRepository / RelationRepository / SearchRepository
