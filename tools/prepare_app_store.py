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
WIDGET_BUNDLE_ID = BUNDLE_ID + ".widgets"
APP_GROUP = "group." + BUNDLE_ID


def export_options(profile, team_id, identities, now=None, bundle_id=BUNDLE_ID, require_group=False):
    now = now or dt.datetime.now(dt.timezone.utc)
    expiry = profile.get("ExpirationDate")
    if not isinstance(expiry, dt.datetime) or expiry.replace(tzinfo=dt.timezone.utc) <= now:
        raise ValueError("The provisioning profile is expired or missing its expiry date.")
    entitlements = profile.get("Entitlements", {})
    if team_id not in profile.get("TeamIdentifier", []):
        raise ValueError("APPLE_TEAM_ID does not match the provisioning profile.")
    if entitlements.get("application-identifier") != f"{team_id}.{bundle_id}":
        raise ValueError(f"The profile must be explicitly registered for {bundle_id} on this team.")
    if require_group and APP_GROUP not in entitlements.get("com.apple.security.application-groups", []):
        raise ValueError(f"Enable {APP_GROUP} for {bundle_id} and regenerate its App Store profile; see WIDGETS.md.")
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
        "provisioningProfiles": {bundle_id: uuid},
        "manageAppVersionAndBuildNumber": False, "uploadSymbols": True,
        "stripSwiftSymbols": True,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("profile", type=Path)
    parser.add_argument("keychain")
    parser.add_argument("output", type=Path)
    parser.add_argument("--widget-profile", type=Path, required=True)
    args = parser.parse_args()
    team = os.environ["APPLE_TEAM_ID"]
    if not re.fullmatch(r"[A-Z0-9]{10}", team):
        raise ValueError("APPLE_TEAM_ID should be the 10-character identifier in your developer membership details.")
    identities = subprocess.check_output(["security", "find-identity", "-v", "-p", "codesigning", args.keychain], text=True)
    options = export_options(plistlib.loads(args.profile.read_bytes()), team, identities, require_group=True)
    widget = export_options(plistlib.loads(args.widget_profile.read_bytes()), team, identities,
                            bundle_id=WIDGET_BUNDLE_ID, require_group=True)
    if widget["signingCertificate"] != options["signingCertificate"]:
        raise ValueError("App and widget profiles must use the same distribution certificate.")
    options["provisioningProfiles"].update(widget["provisioningProfiles"])
    args.output.write_bytes(plistlib.dumps(options))
    with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as env:
        env.write(f"PROFILE_UUID={options['provisioningProfiles'][BUNDLE_ID]}\n")
        env.write(f"WIDGET_PROFILE_UUID={options['provisioningProfiles'][WIDGET_BUNDLE_ID]}\n")
        env.write(f"SIGNING_IDENTITY={options['signingCertificate']}\n")
    print("Validated App Store distribution profile, team, expiry, and matching private-key identity.")


if __name__ == "__main__":
    main()
