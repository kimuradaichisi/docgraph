"""FileScanner - lists .md files respecting .gitignore and include/exclude globs."""


class FileScanner:
    def __init__(
        self,
        include: list[str] | None = None,
        exclude: list[str] | None = None,
        respect_gitignore: bool = True,
    ) -> None:
        self._include = include or ["**/*.md"]
        self._exclude = exclude or []
        self._respect_gitignore = respect_gitignore

    def scan(self, root: str) -> list[str]:
        # TODO: implement with pathspec
        raise NotImplementedError
