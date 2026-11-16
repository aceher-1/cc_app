import datetime as dt
import unittest
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from publication_needed import needed


class PublicationHealthTests(unittest.TestCase):
    def test_stale_empty_missing_and_malformed_publications_require_recovery(self):
        now = dt.datetime(2026, 11, 16, 12, tzinfo=dt.timezone(dt.timedelta(hours=-6)))
        valid = {'schemaVersion': 1, 'updatedAt': '2026-11-16T11:00:00Z',
                 'dates': [{'date': '2026-11-16', 'itemCount': 80}]}
        self.assertFalse(needed(valid, now))
        self.assertTrue(needed({**valid, 'updatedAt': '2026-11-15T17:00:00Z'}, now))
        self.assertTrue(needed({**valid, 'dates': [{'date': '2026-11-16', 'itemCount': 0}]}, now))
        self.assertTrue(needed({**valid, 'dates': []}, now))
        self.assertTrue(needed({}, now))
        self.assertTrue(needed(None, now))
        self.assertTrue(needed({**valid, 'updatedAt': '2026-11-17T00:00:00Z'}, now))
        # Midnight UTC is still yesterday in Milwaukee.
        self.assertTrue(needed({**valid, 'updatedAt': '2026-11-16T00:00:00Z'}, now))
