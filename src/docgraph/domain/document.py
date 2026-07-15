"""Document entity."""
from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class Document:
    """ドキュメントエンティティ。id はパスから決定的に生成する。"""

    id: str
    path: str
    hash: str
    updated_at: datetime
