#!/usr/bin/env python3
"""Regression tests for the Android release contract."""

import importlib.util
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "check-release-invariants.py"
SOURCE = SCRIPT.parents[1]
spec = importlib.util.spec_from_file_location("release_invariants", SCRIPT)
invariants = importlib.util.module_from_spec(spec)
spec.loader.exec_module(invariants)


class ReleaseInvariantTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        names = (
            "android/signing-policy.properties",
            "android/app/build.gradle",
            "android/gradle/wrapper/gradle-wrapper.properties",
            "pubspec.yaml",
            "pubspec.lock",
            "lib/database/database.dart",
        )
        for name in names:
            destination = self.root / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(SOURCE / name, destination)
        for version in range(1, 73):
            if version == 9:
                continue
            for folder, name in (
                ("drift_schemas/db", f"drift_schema_v{version}.json"),
                ("test/drift/db/generated", f"schema_v{version}.dart"),
            ):
                target = self.root / folder / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.touch()
        self.base_pubspec = (self.root / "pubspec.yaml").read_text()
        version_line = next(
            line for line in self.base_pubspec.splitlines()
            if line.startswith("version: ")
        )
        self.version = version_line.split(": ", 1)[1]
        self.semantic_version, build_number = self.version.split("+", 1)
        self.build_number = int(build_number)
        self.base_db = (self.root / "lib/database/database.dart").read_text()
        self.changed_snapshots = ""

    def git_output(self, root, *args):
        if args == ("ls-files", "-s", "--", "flutter"):
            return "160000 " + "f" * 40 + " 0\tflutter\n"
        if args == ("show", "main:pubspec.yaml"):
            return self.base_pubspec
        if args == ("show", "main:lib/database/database.dart"):
            return self.base_db
        if args == ("diff", "--name-only", "main", "HEAD", "--", "drift_schemas/db"):
            return self.changed_snapshots
        raise AssertionError(f"Unexpected Git command: {args}")

    def check(self, history=False):
        with patch.object(invariants, "git_output", side_effect=self.git_output):
            invariants.check_repository(self.root, "main" if history else None)

    def replace(self, name, old, new):
        path = self.root / name
        original = path.read_text()
        self.assertIn(old, original)
        path.write_text(original.replace(old, new, 1))

    def test_current_release_contract(self):
        self.check(history=True)

    def test_application_id_cannot_change(self):
        self.replace("android/signing-policy.properties", "com.presley.flexify", "com.presley.flex")
        with self.assertRaisesRegex(ValueError, "applicationId changed"):
            self.check()

    def test_gradle_canonical_identity_guard_cannot_disappear(self):
        self.replace("android/app/build.gradle", "productionApplicationId != 'com.presley.flexify'", "false")
        with self.assertRaisesRegex(ValueError, "build invariant missing"):
            self.check()

    def test_certificate_identity_cannot_change(self):
        self.replace("android/signing-policy.properties", invariants.CERTIFICATE_SHA256, "a" * 64)
        with self.assertRaisesRegex(ValueError, "certificate changed"):
            self.check()

    def test_signing_verification_cannot_disappear(self):
        self.replace("android/app/build.gradle", "actualCertificateSha256 != expectedReleaseCertificateSha256", "false")
        with self.assertRaisesRegex(ValueError, "build invariant missing"):
            self.check()

    def test_fdroid_unsigned_exception_cannot_disappear(self):
        self.replace("android/app/build.gradle", "System.getenv('fdroidserver')", "false")
        with self.assertRaisesRegex(ValueError, "F-Droid"):
            self.check()

    def test_fdroid_signed_apk_guard_cannot_disappear(self):
        self.replace("android/app/build.gradle", "F-Droid release must be unsigned", "allow signed F-Droid release")
        with self.assertRaisesRegex(ValueError, "build invariant missing"):
            self.check()

    def test_flutter_submodule_must_be_pinned(self):
        with patch.object(invariants, "git_output", return_value="100644 " + "f" * 40 + " 0\tflutter\n"):
            with self.assertRaisesRegex(ValueError, "pinned git submodule"):
                invariants.check_repository(self.root)

    def test_build_number_cannot_decrease(self):
        self.replace("pubspec.yaml", f"version: {self.version}", f"version: {self.semantic_version}+{self.build_number - 1}")
        with self.assertRaisesRegex(ValueError, "build number regressed"):
            self.check(history=True)

    def test_version_change_requires_new_build(self):
        parts = self.semantic_version.split(".")
        parts[-1] = str(int(parts[-1]) + 1)
        self.replace("pubspec.yaml", f"version: {self.version}", f"version: {'.'.join(parts)}+{self.build_number}")
        with self.assertRaisesRegex(ValueError, "requires increasing"):
            self.check(history=True)

    def test_semantic_version_cannot_decrease(self):
        self.replace("pubspec.yaml", f"version: {self.version}", f"version: 0.0.0+{self.build_number + 1}")
        with self.assertRaisesRegex(ValueError, "semantic version regressed"):
            self.check(history=True)

    def test_android_version_code_cannot_overflow(self):
        self.replace("pubspec.yaml", f"version: {self.version}", f"version: {self.semantic_version}+21000000")
        with self.assertRaisesRegex(ValueError, "exceeds Play"):
            self.check()

    def test_missing_current_migration_snapshot_is_rejected(self):
        (self.root / "drift_schemas/db/drift_schema_v72.json").unlink()
        with self.assertRaisesRegex(ValueError, "snapshots differ"):
            self.check()

    def test_old_migration_snapshot_cannot_be_rewritten(self):
        self.changed_snapshots = "drift_schemas/db/drift_schema_v45.json\n"
        with self.assertRaisesRegex(ValueError, "history was rewritten"):
            self.check(history=True)

    def test_new_schema_requires_generated_history(self):
        self.replace("lib/database/database.dart", "schemaVersion => 72", "schemaVersion => 73")
        with self.assertRaisesRegex(ValueError, "snapshots differ"):
            self.check()


    def test_built_apk_metadata_and_signer_are_verified(self):
        import os
        import subprocess

        tools = self.root / "fake-build-tools"
        tools.mkdir()
        apksigner = tools / "apksigner"
        apksigner.write_text(
            "#!/bin/sh\n"
            "printf 'Signer #1 certificate SHA-256 digest: %s\\n' \"$MOCK_CERT\"\n"
        )
        aapt = tools / "aapt"
        aapt.write_text(
            "#!/bin/sh\n"
            "printf \"package: name='%s' versionCode='%s' versionName='2.2.38' compileSdkVersionCodename='17'\\n\" "
            "\"$MOCK_PACKAGE\" \"$MOCK_CODE\"\n"
        )
        apksigner.chmod(0o755)
        aapt.chmod(0o755)
        apk = self.root / "mock.apk"
        apk.touch()

        cases = [
            (invariants.APPLICATION_ID, f"{self.build_number * 100 + 3}", invariants.CERTIFICATE_SHA256, True),
            ("com.presley.flex", f"{self.build_number * 100 + 3}", invariants.CERTIFICATE_SHA256, False),
            (invariants.APPLICATION_ID, f"{(self.build_number - 1) * 100 + 3}", invariants.CERTIFICATE_SHA256, False),
            (invariants.APPLICATION_ID, f"{self.build_number * 100 + 3}", "a" * 64, False),
        ]
        for package, code, cert, accepted in cases:
            with self.subTest(package=package, code=code, cert=cert[:6]):
                env = os.environ.copy()
                env.update(
                    PATH=str(tools) + os.pathsep + env.get("PATH", ""),
                    MOCK_PACKAGE=package,
                    MOCK_CODE=code,
                    MOCK_CERT=cert,
                )
                result = subprocess.run(
                    ["bash", str(SOURCE / "scripts/verify-android-release-signing.sh"), str(apk)],
                    cwd=SOURCE,
                    env=env,
                    text=True,
                    capture_output=True,
                    check=False,
                )
                self.assertEqual(result.returncode == 0, accepted, result.stderr)


if __name__ == "__main__":
    unittest.main()
