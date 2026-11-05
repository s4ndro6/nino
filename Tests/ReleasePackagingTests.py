"""Regression: a release built under umask 077 must be usable by other users."""
from pathlib import Path
import importlib.util
import os
import stat
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('release_permissions', Path(__file__).parents[1] / 'scripts/normalize-release-permissions.py')
assert spec and spec.loader
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PackagingTests(unittest.TestCase):
    def test_restrictive_umask_and_external_symlinks(self) -> None:
        previous = os.umask(0o077)
        try:
            with tempfile.TemporaryDirectory() as temporary:
                base = Path(temporary)
                root = base / 'stage'; root.mkdir()
                binary = root / 'Nino.app/Contents/MacOS/Nino'
                binary.parent.mkdir(parents=True)
                binary.write_bytes(b'not an executable test fixture'); binary.chmod(0o700)
                readme = root / 'LIRE-MOI.txt'; readme.write_text('Installation')
                outside = base / 'outside'; outside.mkdir(); outside.chmod(0o700)
                private = outside / 'private'; private.write_text('fixture'); private.chmod(0o600)
                (root / 'Applications').symlink_to(outside, target_is_directory=True)
                (root / 'file-link').symlink_to(private)
                module.normalize_release(root)
                self.assertEqual(stat.S_IMODE(root.stat().st_mode), 0o755)
                self.assertEqual(stat.S_IMODE(binary.parent.stat().st_mode), 0o755)
                self.assertEqual(stat.S_IMODE(binary.stat().st_mode), 0o755)
                self.assertEqual(stat.S_IMODE(readme.stat().st_mode), 0o644)
                self.assertEqual(stat.S_IMODE(outside.stat().st_mode), 0o700)
                self.assertEqual(stat.S_IMODE(private.stat().st_mode), 0o600)
                self.assertTrue((root / 'Applications').is_symlink())
                with self.assertRaises(ValueError): module.normalize_release(root / 'Applications')
        finally:
            os.umask(previous)


if __name__ == '__main__': unittest.main()
