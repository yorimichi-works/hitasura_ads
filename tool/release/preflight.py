#!/usr/bin/env python3
"""Fail-closed iOS release checks. Uses only the Python standard library.

Local mode is offline. --check-app-store uses Codemagic's existing integration
for a read-only build lookup; --check-profile decodes an already installed
profile locally. Neither mode creates signing resources or uploads a build.
"""

from __future__ import annotations

import argparse
import datetime as dt
import ipaddress
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
from typing import Mapping
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parents[2]
BUNDLE_ID = "com.syamo.hitasuraads"
TEAM_ID = "3W8HVJ3U8W"
APP_ID = "6818519730"


class PreflightError(ValueError):
    """A release prerequisite could not be established."""


def public_https_url(name: str, value: str) -> str:
    """Reject missing, malformed, local and obvious placeholder URLs offline.

    Passing this check does not prove the published page exists or is suitable;
    the release operator must also open and review both pages before building.
    """
    if not value or any(c.isspace() or ord(c) < 32 for c in value) or "\\" in value:
        raise PreflightError(f"{name} must be a nonempty public HTTPS URL")
    try:
        url = urlsplit(value)
        host = (url.hostname or "").encode("idna").decode("ascii").lower().rstrip(".")
        port = url.port
    except (ValueError, UnicodeError) as error:
        raise PreflightError(f"{name} is not a valid URL") from error
    if url.scheme != "https" or not host or url.username is not None or url.password is not None:
        raise PreflightError(f"{name} must use HTTPS without credentials")
    if port not in (None, 443):
        raise PreflightError(f"{name} must use the standard HTTPS port")
    reserved = ("localhost", "local", "internal", "invalid", "test", "example")
    placeholders = ("example.com", "example.org", "example.net")
    if "." not in host or any(host == item or host.endswith("." + item) for item in reserved + placeholders):
        raise PreflightError(f"{name} must not be a local or placeholder URL")
    try:
        ipaddress.ip_address(host)
    except ValueError:
        pass
    else:
        raise PreflightError(f"{name} must use a public domain name, not an IP address")
    if not all(re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", label) for label in host.split(".")):
        raise PreflightError(f"{name} has an invalid domain name")
    return value


def positive_build_number(value: str) -> int:
    if not re.fullmatch(r"[1-9][0-9]*", value):
        raise PreflightError("iOS build number must be a positive integer without leading zeros")
    return int(value)


def read_version(pubspec: str) -> tuple[str, str]:
    match = re.search(r"^version:\s*['\"]?([0-9]+(?:\.[0-9]+){0,2})\+([1-9][0-9]*)['\"]?\s*(?:#.*)?$", pubspec, re.MULTILINE)
    if not match:
        raise PreflightError("pubspec.yaml must define a numeric release version plus build number")
    return match.group(1), match.group(2)


def validate_project(project: str) -> None:
    bundle_ids = re.findall(r"PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);", project)
    if bundle_ids.count(BUNDLE_ID) != 3 or bundle_ids.count(BUNDLE_ID + ".RunnerTests") != 3 or len(bundle_ids) != 6:
        raise PreflightError("All iOS Runner/RunnerTests configurations must use the production bundle IDs")
    teams = re.findall(r"DEVELOPMENT_TEAM\s*=\s*([^;]+);", project)
    if len(teams) != 6 or any(team != TEAM_ID for team in teams):
        raise PreflightError("All iOS target configurations must use the expected Apple team")


def configuration(root: Path, env: Mapping[str, str]) -> dict:
    if env.get("ADMOB_MODE") != "production":
        raise PreflightError("ADMOB_MODE must be production for an App Store IPA")
    if env.get("APP_STORE_APPLE_ID") != APP_ID:
        raise PreflightError(f"APP_STORE_APPLE_ID must be {APP_ID}")
    urls = {name: public_https_url(name, env.get(name, "")) for name in ("PRIVACY_POLICY_URL", "SUPPORT_URL")}
    name, source_number = read_version((root / "pubspec.yaml").read_text())
    number = env.get("IOS_BUILD_NUMBER", source_number)
    positive_build_number(number)
    validate_project((root / "ios/Runner.xcodeproj/project.pbxproj").read_text())
    info = plistlib.loads((root / "ios/Runner/Info.plist").read_bytes())
    expected = {
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleShortVersionString": "$(FLUTTER_BUILD_NAME)",
        "CFBundleVersion": "$(FLUTTER_BUILD_NUMBER)",
        "GADApplicationIdentifier": "$(ADMOB_APP_ID)",
    }
    if any(info.get(key) != value for key, value in expected.items()):
        raise PreflightError("iOS Info.plist must use Flutter versioning and the configured AdMob app ID")
    release_config = (root / "ios/Flutter/Release.xcconfig").read_text()
    if "ADMOB_APP_ID=ca-app-pub-3186852093801241~9948289508" not in release_config:
        raise PreflightError("iOS Release.xcconfig must use the production AdMob application ID")
    return {
        "app_store_apple_id": APP_ID,
        "bundle_id": BUNDLE_ID,
        "team_id": TEAM_ID,
        "version": name,
        "build_number": number,
        "admob_mode": "production",
        "public_urls": urls,
    }


def parse_latest_build(result: subprocess.CompletedProcess, *, app_id: str = APP_ID) -> str | None:
    """Honor exit status first; no errors or unexplained empty output become zero.

    Codemagic CLI >= 0.67.0 --json prints a JSON string for a found build.
    Its no-build path exits successfully with empty stdout and the exact log
    message below on stderr. A future output format change deliberately fails.
    """
    if result.returncode != 0:
        raise PreflightError(
            f"App Store Connect build lookup failed (exit {result.returncode}); "
            "check the existing integration, permissions and network. This is not an initial release."
        )
    output = result.stdout.strip()
    no_build_message = f"Did not find any builds for app {app_id}"
    no_build = no_build_message in {line.strip() for line in result.stderr.splitlines()}
    if not output and no_build:
        return None
    if not output:
        raise PreflightError("Build lookup returned unexplained empty output; refusing to assume no builds")
    try:
        latest = json.loads(output)
    except json.JSONDecodeError as error:
        raise PreflightError("Build lookup did not return the expected JSON build number") from error
    if no_build or not isinstance(latest, str) or not re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", latest):
        raise PreflightError("Build lookup returned an unexpected build number; manual investigation required")
    if all(int(part) == 0 for part in latest.split(".")):
        raise PreflightError("Build lookup returned zero, which is not evidence of an initial release")
    return latest


def require_new_build(candidate: str, latest: str | None, *, allow_initial: bool) -> None:
    number = positive_build_number(candidate)
    if latest is None:
        if not allow_initial:
            raise PreflightError("No uploaded builds were found; explicitly pass --allow-initial-build for the first build")
        return
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", latest):
        raise PreflightError("Cannot compare an invalid existing build number")
    parts = tuple(int(part) for part in latest.split("."))
    latest_version = parts + (0,) * (3 - len(parts))
    if (number, 0, 0) <= latest_version:
        raise PreflightError(f"Build {candidate} must be greater than latest uploaded build {latest}; set IOS_BUILD_NUMBER explicitly")


def lookup_latest_build() -> str | None:
    command = [
        "app-store-connect", "get-latest-build-number", APP_ID,
        "--platform", "IOS", "--all-versions", "--json", "--no-color", "--log-stream", "stderr",
    ]
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=180, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise PreflightError("App Store Connect lookup could not complete; no build number was approved") from error
    return parse_latest_build(result)


def validate_profile(profile: dict, *, now: dt.datetime | None = None) -> None:
    now = now or dt.datetime.now(dt.timezone.utc)
    expiry = profile.get("ExpirationDate")
    if not isinstance(expiry, dt.datetime):
        raise PreflightError("Signing profile has no valid expiration date")
    if expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=dt.timezone.utc)
    if expiry <= now:
        raise PreflightError("Signing profile has expired")
    entitlements = profile.get("Entitlements", {})
    if (
        profile.get("TeamIdentifier") != [TEAM_ID]
        or entitlements.get("com.apple.developer.team-identifier") != TEAM_ID
        or entitlements.get("application-identifier") != f"{TEAM_ID}.{BUNDLE_ID}"
    ):
        raise PreflightError("Signing profile must match this app's exact production bundle ID and Apple team")
    if (
        entitlements.get("get-task-allow") is not False
        or entitlements.get("beta-reports-active") is not True
        or "ProvisionedDevices" in profile
        or profile.get("ProvisionsAllDevices", False)
        or not profile.get("DeveloperCertificates")
    ):
        raise PreflightError("Signing profile must be an App Store distribution profile with a signing certificate")


def check_installed_profile(env: Mapping[str, str]) -> None:
    path = env.get("HITASURA_PROFILE_PATH", "")
    if not path or not Path(path).is_file():
        raise PreflightError("The approved hitasura-app-store-profile must exist in Codemagic before a signed build")
    try:
        result = subprocess.run(["security", "cms", "-D", "-i", path], capture_output=True, timeout=30, check=False)
        if result.returncode != 0:
            raise PreflightError("Could not decode the installed signing profile")
        profile = plistlib.loads(result.stdout)
    except (OSError, subprocess.TimeoutExpired, plistlib.InvalidFileException, ValueError) as error:
        raise PreflightError("Could not read the installed signing profile") from error
    if not isinstance(profile, dict):
        raise PreflightError("The installed signing profile is not a plist dictionary")
    validate_profile(profile)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-app-store", action="store_true")
    parser.add_argument("--allow-initial-build", action="store_true")
    parser.add_argument("--check-profile", action="store_true")
    parser.add_argument("--cm-env", type=Path, help="Append validated version variables only after all checks pass")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args(argv)
    try:
        report = configuration(ROOT, os.environ)
        report["app_store_checked"] = args.check_app_store
        report["profile_checked"] = args.check_profile
        if args.check_app_store:
            latest = lookup_latest_build()
            require_new_build(report["build_number"], latest, allow_initial=args.allow_initial_build)
            report["latest_uploaded_build"] = latest
            report["initial_build"] = latest is None
        if args.check_profile:
            check_installed_profile(os.environ)
        if args.cm_env:
            if not args.check_app_store or not args.check_profile:
                raise PreflightError("Exporting build variables requires both live App Store and installed-profile checks")
            with args.cm_env.open("a", encoding="utf-8") as output:
                output.write(f"RELEASE_BUILD_NAME={report['version']}\nRELEASE_BUILD_NUMBER={report['build_number']}\n")
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    except (PreflightError, OSError, plistlib.InvalidFileException) as error:
        print(f"Release preflight failed: {error}", file=sys.stderr)
        return 1
    print(f"Release configuration passed: {BUNDLE_ID} {report['version']}+{report['build_number']}")
    if not args.check_app_store or not args.check_profile:
        print("Offline checks only: App Store lookup and signing-profile checks must both pass before release.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
