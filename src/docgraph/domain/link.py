"""Link value object."""
from dataclasses import dataclass


@dataclass(frozen=True)
class Link:
    """Markdown 明示リンク or Wiki リンク。"""

    target_path: str
    text: str
    line: int
