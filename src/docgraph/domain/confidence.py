"""Confidence value object."""
from dataclasses import dataclass

MIN_CONFIDENCE = 0.0
MAX_CONFIDENCE = 1.0


@dataclass(frozen=True)
class Confidence:
    """Confidence score constrained to [MIN_CONFIDENCE, MAX_CONFIDENCE]."""

    value: float

    def __post_init__(self) -> None:
        if not MIN_CONFIDENCE <= self.value <= MAX_CONFIDENCE:
            raise ValueError(
                f"Confidence must be in [{MIN_CONFIDENCE}, {MAX_CONFIDENCE}], "
                f"got {self.value}"
            )
