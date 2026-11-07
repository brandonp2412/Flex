#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
policy_file="$repo_root/android/signing-policy.properties"

expected=$(
  sed -n 's/^githubReleaseCertificateSha256=//p' "$policy_file" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cd '0-9a-f'
)

if [[ ${#expected} -ne 64 ]]; then
  echo "Invalid githubReleaseCertificateSha256 in $policy_file" >&2
  exit 2
fi

find_apksigner() {
  if command -v apksigner >/dev/null 2>&1; then
    command -v apksigner
    return
  fi

  local sdk
  for sdk in "${ANDROID_SDK_ROOT:-}" "${ANDROID_HOME:-}" /opt/android-sdk; do
    [[ -n "$sdk" && -d "$sdk/build-tools" ]] || continue
    find "$sdk/build-tools" -mindepth 2 -maxdepth 2 -type f -name apksigner -print \
      | sort -V \
      | tail -n 1
  done | tail -n 1
}

apksigner_bin=$(find_apksigner)
if [[ -z "$apksigner_bin" ]]; then
  echo "Could not find apksigner" >&2
  exit 2
fi

aapt_bin="$(dirname "$apksigner_bin")/aapt"
if [[ ! -x "$aapt_bin" ]]; then
  aapt_bin=$(command -v aapt || true)
fi
if [[ ! -x "$aapt_bin" ]]; then
  echo "Could not find aapt" >&2
  exit 2
fi

expected_package=$(sed -n 's/^productionApplicationId=//p' "$policy_file")
expected_build=$(sed -n 's/^version: [0-9]*\.[0-9]*\.[0-9]*+//p' "$repo_root/pubspec.yaml")
if [[ "$expected_package" != 'com.presley.flexify' || ! "$expected_build" =~ ^[0-9]+$ ]]; then
  echo "Invalid applicationId or build number" >&2
  exit 2
fi

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <apk> [apk ...]" >&2
  exit 2
fi

for apk in "$@"; do
  [[ -f "$apk" ]] || {
    echo "APK not found: $apk" >&2
    exit 2
  }

  actual=$(
    "$apksigner_bin" verify --print-certs "$apk" \
      | sed -n 's/.*certificate SHA-256 digest: //p' \
      | head -n 1 \
      | tr '[:upper:]' '[:lower:]' \
      | tr -cd '0-9a-f'
  )

  if [[ "$actual" != "$expected" ]]; then
    echo "Wrong signer for $apk" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   ${actual:-<missing>}" >&2
    exit 1
  fi

  package_line=$("$aapt_bin" dump badging "$apk" | sed -n '/^package:/p' | head -n 1)
  actual_package=$(printf '%s\n' "$package_line" | sed -n "s/^package: name='\([^']*\)'.*/\1/p")
  actual_code=$(printf '%s\n' "$package_line" | sed -n "s/.*versionCode='\([0-9]*\)'.*/\1/p")
  if [[ "$actual_package" != "$expected_package" || ! "$actual_code" =~ ^[0-9]+$ ]]; then
    echo "Wrong package ID or missing Android versionCode for $apk" >&2
    exit 1
  fi
  min_code=$((expected_build * 100 + 1))
  max_code=$((expected_build * 100 + 3))
  if (( actual_code < min_code || actual_code > max_code )); then
    echo "Wrong Android versionCode for $apk: $actual_code (expected $min_code..$max_code)" >&2
    exit 1
  fi

  echo "Verified release APK: $apk ($actual_package, versionCode $actual_code, signer $actual)"
done
