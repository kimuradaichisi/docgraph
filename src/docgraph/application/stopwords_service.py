"""StopwordsService - loads and provides stopword sets."""
from pathlib import Path


class StopwordsService:
    """Loads stopwords from one or more text files and answers containment queries."""

    def __init__(self, paths: list[str]) -> None:
        self._words: set[str] = set()
        for p in paths:
            self._load(Path(p))

    def _load(self, path: Path) -> None:
        if not path.exists():
            return
        for raw_line in path.read_text(encoding="utf-8").splitlines():
            word = raw_line.strip()
            if not word or word.startswith("#"):
                continue
            self._words.add(word)

    def contains(self, word: str) -> bool:
        return word in self._words

    def as_set(self) -> set[str]:
        return set(self._words)
