import copy
import datetime as dt
import hashlib
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from prepare_app_store import BUNDLE_ID, export_options


class AppStoreSigningTests(unittest.TestCase):
    def setUp(self):
        self.now = dt.datetime(2026, 10, 15, tzinfo=dt.timezone.utc)
        self.team = "TESTTEAM01"
        # Synthetic bytes, not a certificate or credential.
        self.identity = hashlib.sha1(b"synthetic-certificate").hexdigest().upper()
        self.profile = {
            "ExpirationDate": dt.datetime(2027, 1, 1), "TeamIdentifier": [self.team],
            "UUID": "11111111-2222-3333-4444-555555555555",
            "DeveloperCertificates": [b"synthetic-certificate"],
            "Entitlements": {"application-identifier": f"{self.team}.{BUNDLE_ID}",
                             "com.apple.developer.team-identifier": self.team, "get-task-allow": False},
        }

    def test_app_store_export_pins_bundle_profile_and_matching_identity(self):
        options = export_options(self.profile, self.team, self.identity, self.now)
        self.assertEqual(options["method"], "app-store-connect")
        self.assertEqual(options["provisioningProfiles"], {BUNDLE_ID: self.profile["UUID"]})
        self.assertEqual(options["signingCertificate"], self.identity)
        self.assertFalse(options["manageAppVersionAndBuildNumber"])

    def test_rejects_wrong_app_team_expiry_and_non_store_profile(self):
        variants = []
        for key, value in [("ExpirationDate", dt.datetime(2026, 1, 1)),
                           ("TeamIdentifier", ["OTHERTEAM1"]), ("ProvisionedDevices", ["fake-device"]),
                           ("ProvisionsAllDevices", True)]:
            profile = copy.deepcopy(self.profile)
            profile[key] = value
            variants.append(profile)
        for key, value in [("application-identifier", f"{self.team}.other.app"),
                           ("get-task-allow", True), ("com.apple.developer.team-identifier", "OTHERTEAM1")]:
            profile = copy.deepcopy(self.profile)
            profile["Entitlements"][key] = value
            variants.append(profile)
        for profile in variants:
            with self.subTest(profile=profile), self.assertRaises(ValueError):
                export_options(profile, self.team, self.identity, self.now)

    def test_rejects_missing_or_unmatched_private_key_identity(self):
        with self.assertRaisesRegex(ValueError, "private key"):
            export_options(self.profile, self.team, "0 valid identities found", self.now)


if __name__ == "__main__":
    unittest.main()
