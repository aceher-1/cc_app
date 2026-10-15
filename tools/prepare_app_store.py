"""Validate a decoded Apple profile and prepare manual App Store export options.

Used only on the cloud Mac. Private credentials remain in RUNNER_TEMP.
"""
import argparse
import datetime as dt
import hashlib
import os
from pathlib import Path
import plistlib
import re
import subprocess

BUNDLE_ID = "com.aceher.msoedining"


def export_options(profile, team_id, identities, now=None):
    now = now or dt.datetime.now(dt.timezone.utc)
    expiry = profile.get("ExpirationDate")
    if not isinstance(expiry, dt.datetime) or expiry.replace(tzinfo=dt.timezone.utc) <= now:
        raise ValueError("The provisioning profile is expired or missing its expiry date.")
    entitlements = profile.get("Entitlements", {})
    if team_id not in profile.get("TeamIdentifier", []):
        raise ValueError("APPLE_TEAM_ID does not match the provisioning profile.")
    if entitlements.get("application-identifier") != f"{team_id}.{BUNDLE_ID}":
        raise ValueError(f"The profile must be explicitly registered for {BUNDLE_ID} on this team.")
    if entitlements.get("com.apple.developer.team-identifier") != team_id:
        raise ValueError("The profile's signing entitlement does not match APPLE_TEAM_ID.")
    if entitlements.get("get-task-allow", True) or "ProvisionedDevices" in profile or profile.get("ProvisionsAllDevices"):
        raise ValueError("Use an App Store Connect distribution profile, not development, Ad Hoc, or enterprise.")
    uuid = profile.get("UUID", "")
    if not re.fullmatch(r"[A-Fa-f0-9-]{36}", uuid):
        raise ValueError("The provisioning profile UUID is invalid.")
    fingerprints = [hashlib.sha1(cert).hexdigest().upper() for cert in profile.get("DeveloperCertificates", [])]
    identity = next((fingerprint for fingerprint in fingerprints if fingerprint in identities), None)
    if identity is None:
        raise ValueError("The P12 must include a valid distribution certificate AND its private key matching this profile.")
    return {
        "method": "app-store-connect", "destination": "export", "teamID": team_id,
        "signingStyle": "manual", "signingCertificate": identity,
        "provisioningProfiles": {BUNDLE_ID: uuid},
        "manageAppVersionAndBuildNumber": False, "uploadSymbols": True,
        "stripSwiftSymbols": True,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("profile", type=Path)
    parser.add_argument("keychain")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    team = os.environ["APPLE_TEAM_ID"]
    if not re.fullmatch(r"[A-Z0-9]{10}", team):
        raise ValueError("APPLE_TEAM_ID should be the 10-character identifier in your developer membership details.")
    identities = subprocess.check_output(["security", "find-identity", "-v", "-p", "codesigning", args.keychain], text=True)
    options = export_options(plistlib.loads(args.profile.read_bytes()), team, identities)
    args.output.write_bytes(plistlib.dumps(options))
    with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as env:
        env.write(f"PROFILE_UUID={options['provisioningProfiles'][BUNDLE_ID]}\n")
        env.write(f"SIGNING_IDENTITY={options['signingCertificate']}\n")
    print("Validated App Store distribution profile, team, expiry, and matching private-key identity.")


if __name__ == "__main__":
    main()
