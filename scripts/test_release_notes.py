import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import release_notes

class ReleaseNotesTests(unittest.TestCase):
    def test_uses_exact_authored_notes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.txt"
            source.write_text("Fixed reminders after restarting your phone.\n", encoding="utf-8")
            paths = [root / "github.txt", root / "store" / "default.txt"]
            with patch("sys.argv", ["release_notes.py", str(source), *map(str, paths)]):
                self.assertEqual(release_notes.main(), 0)
            for path in paths:
                self.assertEqual(path.read_bytes(), source.read_bytes())

    def test_rejects_missing_or_bad_notes(self):
        for notes in ["", " ", "Bug fixes and improvements", "fix(android): do something", "• chore: cleanup", "x"*501, "😀"*251]:
            with self.subTest(notes=notes[:30]):
                with self.assertRaises(ValueError):
                    release_notes.validate(notes)

    def test_accepts_500_character_limit(self):
        self.assertEqual(len(release_notes.validate("x"*500).strip()), 500)

if __name__ == "__main__":
    unittest.main()
