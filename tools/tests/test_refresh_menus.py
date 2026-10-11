import contextlib
import datetime as dt
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from refresh_menus import build, validate_menu


class SharedMenuTests(unittest.TestCase):
    def test_all_dates_have_valid_envelopes_and_no_client_key(self):
        with tempfile.TemporaryDirectory() as directory, contextlib.redirect_stdout(io.StringIO()):
            requests = []
            def fetch(day):
                requests.append(day)
                return [{"name": "Lunch", "groups": [{"name": "Station", "items": [{"formalName": "Test rice", "ingredients": "Rice", "allergens": []}]}]}]
            build(directory, dt.date(2026, 10, 11), dt.datetime(2026, 10, 11, 10, tzinfo=dt.timezone.utc), fetch)
            self.assertEqual(len(requests), 16)
            self.assertEqual(len(set(requests)), 16)
            self.assertEqual(requests[0], "2026-10-10")
            self.assertEqual(requests[-1], "2026-10-25")
            data = json.loads((Path(directory) / "api/2026-10-11.json").read_text())
            self.assertEqual(data["updatedAt"], "2026-10-11T10:00:00Z")
            self.assertEqual(data["date"], "2026-10-11")
            self.assertEqual(set(data), {"schemaVersion", "date", "updatedAt", "source", "meals"})
            self.assertEqual(json.loads((Path(directory) / "manifest.json").read_text())["dates"][0]["itemCount"], 1)

    def test_failure_does_not_replace_previous_snapshot(self):
        with tempfile.TemporaryDirectory() as directory, contextlib.redirect_stdout(io.StringIO()):
            api = Path(directory) / "api"
            api.mkdir()
            previous = api / "2026-10-11.json"
            previous.write_text("previous snapshot")
            def fetch(day):
                if day == "2026-10-12":
                    raise RuntimeError("Upstream unavailable")
                return []
            with self.assertRaises(RuntimeError):
                build(directory, dt.date(2026, 10, 11), dt.datetime.now(dt.timezone.utc), fetch)
            self.assertEqual(previous.read_text(), "previous snapshot")
            self.assertEqual(list(api.glob("*.json")), [previous])

    def test_schema_errors_are_not_published_as_empty_menus(self):
        for invalid in [{"error": "upstream failure"}, [{"name": "Dinner"}], [{"name": "Lunch", "groups": [{"name": "Grill", "items": [{}]}]}]]:
            with self.assertRaises(ValueError):
                validate_menu(invalid)
        self.assertEqual(validate_menu([]), 0)


if __name__ == "__main__":
    unittest.main()
