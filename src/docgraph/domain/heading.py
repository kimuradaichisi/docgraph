"""Heading value object."""
from dataclasses import dataclass

MIN_HEADING_LEVEL = 1
MAX_HEADING_LEVEL = 6


@dataclass(frozen=True)
class Heading:
    """Markdown heading. level range: MIN_HEADING_LEVEL..MAX_HEADING_LEVEL."""

    level: int
    text: str
    line: int

    def __post_init__(self) -> None:
        if not MIN_HEADING_LEVEL <= self.level <= MAX_HEADING_LEVEL:
            raise ValueError(
                f"Heading level must be {MIN_HEADING_LEVEL}-{MAX_HEADING_LEVEL}, "
                f"got {self.level}"
            )
