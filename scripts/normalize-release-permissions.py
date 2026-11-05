"""Make only a staged distribution tree readable on another Mac account."""
from pathlib import Path
import os
import stat
import sys


def normalize_release(root: Path) -> None:
    if root.is_symlink() or not root.is_dir():
        raise ValueError('Expected a real staging directory')
    for current, dirs, files in os.walk(root, followlinks=False):
        directory = Path(current)
        directory.chmod(0o755)
        dirs[:] = [name for name in dirs if not (directory / name).is_symlink()]
        for name in files:
            path = directory / name
            mode = path.lstat().st_mode
            if stat.S_ISLNK(mode):
                continue
            if not stat.S_ISREG(mode):
                raise ValueError(f'Unexpected package entry: {path.name}')
            path.chmod(0o755 if mode & 0o111 else 0o644)


if __name__ == '__main__':
    normalize_release(Path(sys.argv[1]))
