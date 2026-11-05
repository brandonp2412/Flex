#!/usr/bin/env python3
"""Fail closed when Flex's existing Android release contract changes unexpectedly."""

import argparse
import re
import subprocess
import sys
from pathlib import Path

APPLICATION_ID = "com.presley.flexify"
CERTIFICATE_SHA256 = "011ee1a6e4e5ecd675f67fbf3d78ad82614a7a7a3f24ed71cc9c417154a0f0fd"
MAX_ANDROID_VERSION_CODE = 2_100_000_000
HISTORIC_MISSING_DRIFT_SNAPSHOTS = {9}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def unique_match(pattern: str, text: str, description: str) -> str:
    matches = re.findall(pattern, text, flags=re.MULTILINE)
    require(len(matches) == 1, f"Expected exactly one {description}; found {len(matches)}")
    return matches[0]


def parse_version(pubspec: str) -> tuple[tuple[int, int, int], int]:
    raw = unique_match(r"^version:\s*(\d+\.\d+\.\d+\+\d+)\s*$", pubspec, "pubspec version")
    name, build = raw.split("+")
    version = tuple(int(part) for part in name.split("."))
    build_number = int(build)
    require(build_number > 0, "Android build number must be positive")
    require(build_number * 100 + 3 <= MAX_ANDROID_VERSION_CODE, "Android versionCode exceeds Play's maximum")
    return version, build_number


def schema_version(database: str) -> int:
    value = unique_match(r"\bint\s+get\s+schemaVersion\s*=>\s*(\d+)\s*;", database, "Drift schemaVersion")
    return int(value)


def git_output(root: Path, *args: str) -> str:
    result = subprocess.run(["git", *args], cwd=root, text=True, capture_output=True, check=False)
    require(result.returncode == 0, f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout


def check_repository(root: Path, base_ref: str | None = None) -> None:
    properties = (root / "android/signing-policy.properties").read_text()
    application_id = unique_match(r"^productionApplicationId=([^\r\n]+)$", properties, "production applicationId")
    certificate = unique_match(r"^githubReleaseCertificateSha256=([^\r\n]+)$", properties, "release certificate")
    require(application_id == APPLICATION_ID, f"Android applicationId changed: {application_id}")
    require(certificate.lower() == CERTIFICATE_SHA256, "Android release signing certificate changed")

    gradle = (root / "android/app/build.gradle").read_text()
    for fragment in (
        "productionApplicationId != 'com.presley.flexify'",
        "expectedReleaseCertificateSha256 != '" + CERTIFICATE_SHA256 + "'",
        "applicationId productionApplicationId",
        "versionCode flutterVersionCode.toInteger()",
        "signingCertificateSha256(signingConfig)",
        "actualCertificateSha256 != expectedReleaseCertificateSha256",
        "buildType.name == 'release' && isFdroidBuild",
        "F-Droid release must be unsigned",
        "variant.versionCode * 100 + abiVersionCode",
        "variant.versionCode * 100 + 3",
    ):
        require(fragment in gradle, f"Android build invariant missing: {fragment}")
    require("System.getenv('fdroidserver')" in gradle and "System.getenv('home_vagrant')" in gradle,
            "F-Droid unsigned build detection changed")
    require(bool(re.search(r'ndkVersion\s*=\s*"\d+\.\d+\.\d+"', gradle)), "Android NDK is not pinned")

    wrapper = (root / "android/gradle/wrapper/gradle-wrapper.properties").read_text()
    require(bool(re.search(r"^distributionSha256Sum=[0-9a-f]{64}$", wrapper, re.MULTILINE)),
            "Gradle distribution checksum is missing")
    require((root / "pubspec.lock").is_file(), "Missing locked Flutter dependencies")
    submodule = git_output(root, "ls-files", "-s", "--", "flutter")
    require(bool(re.fullmatch(r"160000 [0-9a-f]{40} 0\tflutter\n?", submodule)),
            "Flutter SDK must remain a pinned git submodule")

    version, build = parse_version((root / "pubspec.yaml").read_text())
    database = (root / "lib/database/database.dart").read_text()
    current_schema = schema_version(database)
    require(current_schema >= 1, "Invalid Drift schema version")
    for folder, prefix, suffix in (
        ("drift_schemas/db", "drift_schema_v", ".json"),
        ("test/drift/db/generated", "schema_v", ".dart"),
    ):
        path = root / folder
        versions = sorted(
            int(match.group(1))
            for child in path.iterdir()
            if (match := re.fullmatch(re.escape(prefix) + r"(\d+)" + re.escape(suffix), child.name))
        )
        expected = sorted(set(range(1, current_schema + 1)) - HISTORIC_MISSING_DRIFT_SNAPSHOTS)
        require(versions == expected,
                f"{folder} snapshots differ from expected versions through {current_schema}")

    if base_ref:
        previous_version, previous_build = parse_version(
            git_output(root, "show", f"{base_ref}:pubspec.yaml")
        )
        require(version >= previous_version, "Android semantic version regressed")
        require(build >= previous_build, "Android build number regressed")
        require(version == previous_version or build > previous_build,
                "Changing app version requires increasing the build number")

        previous_schema = schema_version(
            git_output(root, "show", f"{base_ref}:lib/database/database.dart")
        )
        require(current_schema >= previous_schema, "Drift schemaVersion regressed")
        changed = git_output(
            root, "diff", "--name-only", base_ref, "HEAD", "--", "drift_schemas/db"
        )
        for name in changed.splitlines():
            match = re.fullmatch(r"drift_schemas/db/drift_schema_v(\d+)\.json", name)
            if match:
                require(int(match.group(1)) > previous_schema,
                        f"Committed Drift history was rewritten: {name}")

    print(f"Android release contract OK: {APPLICATION_ID}, build {build}, schema {current_schema}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--base-ref", help="Compare versions and immutable migration history to a Git ref")
    arguments = parser.parse_args()
    try:
        check_repository(arguments.root, arguments.base_ref)
    except (ValueError, OSError) as error:
        print(f"Release invariant failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
