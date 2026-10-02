from __future__ import annotations

import copy
import datetime as dt
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "preflight.py"
spec = importlib.util.spec_from_file_location("release_preflight", SCRIPT)
preflight = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preflight)


def response(stdout="", stderr="", returncode=0):
    return subprocess.CompletedProcess(["app-store-connect"], returncode, stdout, stderr)


class UrlTests(unittest.TestCase):
    def test_accepts_public_https_url(self):
        value = "https://support.syamo.jp/hitasura/privacy?lang=ja#contact"
        self.assertEqual(preflight.public_https_url("URL", value), value)

    def test_rejects_unsafe_or_placeholder_urls(self):
        values = [
            "", " https://support.syamo.jp", "https://support.syamo.jp\n",
            "https://support.syamo.jp/a b", "http://support.syamo.jp", "mailto:help@syamo.jp",
            "https://user:password@support.syamo.jp", "https://user@support.syamo.jp",
            "https://example.com/privacy", "https://privacy.example.org", "https://example.net",
            "https://app.test/privacy", "https://app.invalid", "https://localhost",
            "https://app.local", "https://app.internal", "https://app.example",
            "https://127.0.0.1", "https://[::1]", "https://192.168.1.1", "https://8.8.8.8",
            "https://support.syamo.jp:bad", "https://support.syamo.jp:8080", "https://[bad",
            "https://support.syamo.jp\\@localhost", "https://-bad.syamo.jp", "https://bad_.syamo.jp",
        ]
        for value in values:
            with self.subTest(value=value), self.assertRaises(preflight.PreflightError):
                preflight.public_https_url("URL", value)


class VersionTests(unittest.TestCase):
    def test_pubspec_version_is_preserved(self):
        self.assertEqual(preflight.read_version("name: app\nversion: 1.0.0+1\n"), ("1.0.0", "1"))

    def test_pubspec_can_have_quotes_and_comment(self):
        self.assertEqual(preflight.read_version('version: "1.2.3+45" # release\n'), ("1.2.3", "45"))

    def test_rejects_invalid_pubspec_release_versions(self):
        for value in ["version: 1.0.0", "version: 1.0.0+0", "version: 1.0.0-beta+2", "version: 1.0.0+01"]:
            with self.subTest(value=value), self.assertRaises(preflight.PreflightError):
                preflight.read_version(value)

    def test_rejects_invalid_candidate_build_numbers(self):
        for value in ["", "0", "01", "-1", "1.2", "1e2", " 2", "2\n", "true", "$(cmd)"]:
            with self.subTest(value=value), self.assertRaises(preflight.PreflightError):
                preflight.positive_build_number(value)

    def test_build_number_compares_numerically(self):
        preflight.require_new_build("10", "9", allow_initial=False)
        preflight.require_new_build("3", "2.99.99", allow_initial=False)

    def test_rejects_equal_and_older_numbers_even_when_initial_is_allowed(self):
        for candidate, latest in [("1", "1"), ("2", "3"), ("9", "10"), ("2", "2.0.0"), ("2", "2.1")]:
            with self.subTest(candidate=candidate, latest=latest), self.assertRaises(preflight.PreflightError):
                preflight.require_new_build(candidate, latest, allow_initial=True)

    def test_first_build_requires_explicit_permission(self):
        with self.assertRaises(preflight.PreflightError):
            preflight.require_new_build("1", None, allow_initial=False)
        preflight.require_new_build("1", None, allow_initial=True)


class AppStoreLookupTests(unittest.TestCase):
    def test_parses_documented_json_string(self):
        self.assertEqual(preflight.parse_latest_build(response('"9"\n', "Found build number 9\n")), "9")
        self.assertEqual(preflight.parse_latest_build(response('"2.3.1"')), "2.3.1")

    def test_accepts_only_recognized_successful_no_build_state(self):
        result = response("", f"Did not find any builds for app {preflight.APP_ID}\n")
        self.assertIsNone(preflight.parse_latest_build(result))

    def test_nonzero_exit_never_becomes_initial_build(self):
        for stdout, stderr in [
            ("", "401 Unauthorized"),
            ('"999"', "API failure"),
            ("", f"Did not find any builds for app {preflight.APP_ID}"),
        ]:
            with self.subTest(stdout=stdout, stderr=stderr), self.assertRaises(preflight.PreflightError):
                preflight.parse_latest_build(response(stdout, stderr, returncode=1))

    def test_rejects_empty_missing_app_and_auth_error_output(self):
        for stderr in ["", "Unauthorized", "Did not find any builds for app 123", "null"]:
            with self.subTest(stderr=stderr), self.assertRaises(preflight.PreflightError):
                preflight.parse_latest_build(response("", stderr))

    def test_rejects_unexpected_json_and_zero_sentinel(self):
        for stdout in ["null", "0", '"0"', '"0.0.0"', '""', "true", "[]", "{}", '{"buildNumber":"4"}', "4", '"-2"', '"abc"', '"1.2.3.4"', 'log\n"4"']:
            with self.subTest(stdout=stdout), self.assertRaises(preflight.PreflightError):
                preflight.parse_latest_build(response(stdout))

    def test_rejects_contradictory_no_build_output(self):
        with self.assertRaises(preflight.PreflightError):
            preflight.parse_latest_build(response('"5"', f"Did not find any builds for app {preflight.APP_ID}"))

    @mock.patch.object(preflight.subprocess, "run")
    def test_uses_all_versions_and_ios_read_only_cli(self, run):
        run.return_value = response('"12"')
        self.assertEqual(preflight.lookup_latest_build(), "12")
        command = run.call_args.args[0]
        self.assertEqual(command[:3], ["app-store-connect", "get-latest-build-number", preflight.APP_ID])
        self.assertIn("--all-versions", command)
        self.assertIn("--json", command)
        self.assertEqual(command[command.index("--platform") + 1], "IOS")
        self.assertTrue(run.call_args.kwargs["capture_output"])
        self.assertEqual(run.call_args.kwargs["timeout"], 180)

    @mock.patch.object(preflight.subprocess, "run")
    def test_missing_outdated_cli_and_timeout_fail_closed(self, run):
        for error in [FileNotFoundError(), subprocess.TimeoutExpired("app-store-connect", 180)]:
            run.side_effect = error
            with self.subTest(error=type(error)), self.assertRaises(preflight.PreflightError):
                preflight.lookup_latest_build()
        run.side_effect = None
        run.return_value = response("", "unrecognized arguments: --all-versions", returncode=2)
        with self.assertRaises(preflight.PreflightError):
            preflight.lookup_latest_build()


class ProfileTests(unittest.TestCase):
    def setUp(self):
        self.now = dt.datetime(2026, 10, 2, tzinfo=dt.timezone.utc)
        self.profile = {
            "ExpirationDate": dt.datetime(2027, 10, 2),
            "TeamIdentifier": [preflight.TEAM_ID],
            "DeveloperCertificates": [b"certificate-fixture"],
            "Entitlements": {
                "application-identifier": f"{preflight.TEAM_ID}.{preflight.BUNDLE_ID}",
                "com.apple.developer.team-identifier": preflight.TEAM_ID,
                "get-task-allow": False,
                "beta-reports-active": True,
            },
        }

    def test_valid_app_store_profile(self):
        preflight.validate_profile(self.profile, now=self.now)

    def test_rejects_expired_development_ad_hoc_enterprise_and_wrong_team(self):
        changes = [
            {"ExpirationDate": self.now}, {"ExpirationDate": None},
            {"TeamIdentifier": ["OTHERTEAM1"]}, {"ProvisionedDevices": []},
            {"ProvisionsAllDevices": True}, {"DeveloperCertificates": []},
        ]
        for change in changes:
            with self.subTest(change=change), self.assertRaises(preflight.PreflightError):
                preflight.validate_profile(self.profile | change, now=self.now)

    def test_rejects_wrong_app_wildcard_and_development_entitlements(self):
        for key, value in [
            ("application-identifier", f"{preflight.TEAM_ID}.*"),
            ("application-identifier", f"{preflight.TEAM_ID}.com.syamo.otherapp"),
            ("com.apple.developer.team-identifier", "OTHERTEAM1"),
            ("get-task-allow", True), ("get-task-allow", None),
            ("beta-reports-active", False),
        ]:
            profile = copy.deepcopy(self.profile)
            profile["Entitlements"][key] = value
            with self.subTest(key=key, value=value), self.assertRaises(preflight.PreflightError):
                preflight.validate_profile(profile, now=self.now)

    def test_missing_profile_is_explicit_failure(self):
        with self.assertRaises(preflight.PreflightError):
            preflight.check_installed_profile({})


class RepositoryConfigurationTests(unittest.TestCase):
    def setUp(self):
        # Test fixtures only; these URLs are never used as workflow defaults.
        self.env = {
            "ADMOB_MODE": "production", "APP_STORE_APPLE_ID": preflight.APP_ID,
            "PRIVACY_POLICY_URL": "https://support.syamo.jp/privacy",
            "SUPPORT_URL": "https://support.syamo.jp/hitasura",
        }

    def test_repository_metadata_and_version(self):
        report = preflight.configuration(preflight.ROOT, self.env)
        self.assertEqual(report["version"], "1.0.0")
        self.assertEqual(report["build_number"], "1")
        self.assertEqual(report["bundle_id"], "com.syamo.hitasuraads")

    def test_manual_build_override_does_not_edit_pubspec(self):
        original = (preflight.ROOT / "pubspec.yaml").read_bytes()
        report = preflight.configuration(preflight.ROOT, self.env | {"IOS_BUILD_NUMBER": "2"})
        self.assertEqual(report["build_number"], "2")
        self.assertEqual((preflight.ROOT / "pubspec.yaml").read_bytes(), original)

    def test_missing_urls_wrong_app_and_nonproduction_ads_fail(self):
        for key, value in [("PRIVACY_POLICY_URL", ""), ("SUPPORT_URL", ""), ("APP_STORE_APPLE_ID", "123"), ("ADMOB_MODE", "test")]:
            with self.subTest(key=key), self.assertRaises(preflight.PreflightError):
                preflight.configuration(preflight.ROOT, self.env | {key: value})

    def test_placeholder_project_and_wrong_team_fail(self):
        project = (preflight.ROOT / "ios/Runner.xcodeproj/project.pbxproj").read_text()
        for invalid in [project.replace(preflight.BUNDLE_ID, "com.example.app"), project.replace(preflight.TEAM_ID, "OTHERTEAM1")]:
            with self.assertRaises(preflight.PreflightError):
                preflight.validate_project(invalid)

    def test_workflow_has_no_auto_trigger_publisher_or_signing_creation(self):
        workflow = (preflight.ROOT / "codemagic.yaml").read_text().split("  ios-app-store-ipa:", 1)[1]
        for forbidden in ["triggering:", "publishing:", "fetch-signing-files", "--create", "app-store-connect publish"]:
            self.assertNotIn(forbidden, workflow)
        self.assertIn("max_build_duration: 60", workflow)
        self.assertIn("profile: hitasura-app-store-profile", workflow)
        self.assertIn("- cirno-app-store", workflow)
        self.assertIn("app_store_connect: codemagic", workflow)
        self.assertIn("--check-app-store --allow-initial-build --check-profile", workflow)
        self.assertIn("flutter analyze --no-pub", workflow)
        self.assertIn("flutter test --no-pub", workflow)
        self.assertIn('--dart-define="ADMOB_MODE=${ADMOB_MODE:?}"', workflow)
        self.assertIn('--dart-define="PRIVACY_POLICY_URL=${PRIVACY_POLICY_URL:?}"', workflow)
        self.assertIn('--dart-define="SUPPORT_URL=${SUPPORT_URL:?}"', workflow)

    @mock.patch.dict(preflight.os.environ, {}, clear=True)
    def test_failed_configuration_exports_nothing(self):
        with tempfile.TemporaryDirectory() as temp:
            env_file = Path(temp) / "env"
            self.assertEqual(preflight.main(["--cm-env", str(env_file)]), 1)
            self.assertFalse(env_file.exists())

    def test_offline_mode_cannot_export_approved_build_variables(self):
        with tempfile.TemporaryDirectory() as temp, mock.patch.dict(preflight.os.environ, self.env, clear=True):
            env_file = Path(temp) / "env"
            self.assertEqual(preflight.main(["--cm-env", str(env_file)]), 1)
            self.assertFalse(env_file.exists())

    @mock.patch.object(preflight, "check_installed_profile")
    @mock.patch.object(preflight, "lookup_latest_build", return_value=None)
    def test_verified_initial_build_exports_only_validated_version(self, lookup, profile):
        with tempfile.TemporaryDirectory() as temp, mock.patch.dict(preflight.os.environ, self.env, clear=True):
            env_file, report_file = Path(temp) / "env", Path(temp) / "report.json"
            code = preflight.main([
                "--check-app-store", "--allow-initial-build", "--check-profile",
                "--cm-env", str(env_file), "--report", str(report_file),
            ])
            self.assertEqual(code, 0)
            self.assertEqual(env_file.read_text(), "RELEASE_BUILD_NAME=1.0.0\nRELEASE_BUILD_NUMBER=1\n")
            report = json.loads(report_file.read_text())
            self.assertTrue(report["app_store_checked"])
            self.assertTrue(report["profile_checked"])
            self.assertTrue(report["initial_build"])
            self.assertIsNone(report["latest_uploaded_build"])
        lookup.assert_called_once()
        profile.assert_called_once()

    @mock.patch.object(preflight, "lookup_latest_build", return_value="1")
    def test_reused_build_exports_nothing(self, lookup):
        with tempfile.TemporaryDirectory() as temp, mock.patch.dict(preflight.os.environ, self.env, clear=True):
            env_file = Path(temp) / "env"
            self.assertEqual(preflight.main([
                "--check-app-store", "--allow-initial-build", "--check-profile", "--cm-env", str(env_file),
            ]), 1)
            self.assertFalse(env_file.exists())


if __name__ == "__main__":
    unittest.main()
