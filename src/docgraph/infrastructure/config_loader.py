"""ConfigLoader - loads docgraph.toml."""
import tomllib
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class ScanConfig:
    include: list[str] = field(default_factory=lambda: ["**/*.md"])
    exclude: list[str] = field(default_factory=list)


@dataclass
class StopwordsConfig:
    files: list[str] = field(default_factory=list)


@dataclass
class RelationConfig:
    name_mention_min_length: int = 3
    heading_mention_min_length: int = 3
    name_mention_confidence: float = 0.7
    heading_mention_confidence: float = 0.6


@dataclass
class Config:
    project_name: str = ""
    root: str = "."
    scan: ScanConfig = field(default_factory=ScanConfig)
    stopwords: StopwordsConfig = field(default_factory=StopwordsConfig)
    relation: RelationConfig = field(default_factory=RelationConfig)


def load_config(path: Path) -> Config:
    if not path.exists():
        return Config()
    _ = tomllib.loads(path.read_text(encoding="utf-8"))
    # TODO: proper mapping from parsed dict to Config
    return Config()
